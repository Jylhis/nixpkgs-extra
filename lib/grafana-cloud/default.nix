# Shared option schema and Alloy (River) config generator for the
# services.grafanaCloud NixOS and Home Manager modules.
#
# Endpoints and instance IDs are rendered into the config. The Cloud Access
# Policy token is read by Alloy from GC_TOKEN (an EnvironmentFile), never the
# store.
{ lib }:
let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    mapAttrsToList
    mkEnableOption
    mkOption
    optional
    optionalAttrs
    optionalString
    optionals
    types
    ;

  # Render a Nix value as an Alloy (River) expression. JSON string escapes
  # are valid River string escapes.
  riverValue =
    v:
    if builtins.isString v then
      builtins.toJSON v
    else if builtins.isBool v then
      (if v then "true" else "false")
    else if builtins.isInt v || builtins.isFloat v then
      toString v
    else if builtins.isList v then
      "[" + concatMapStringsSep ", " riverValue v + "]"
    else if builtins.isAttrs v then
      "{" + concatStringsSep ", " (mapAttrsToList (k: val: "${k} = ${riverValue val}") v) + "}"
    else
      throw "grafanaCloud: cannot render ${builtins.typeOf v} as River value";

  mkScrapeTarget =
    t:
    {
      __address__ = t.address;
      inherit (t) job;
    }
    // t.labels;

  mkLogFileTarget = f: { __path__ = f.path; } // f.labels;

  # Labels attached to every signal.
  mkLabels =
    cfg: optionalAttrs (cfg.environment != null) { env = cfg.environment; } // cfg.externalLabels;

  # Endpoint block of the remote-write style sinks.
  mkEndpoint = signal: ''
    endpoint {
      url = ${riverValue signal.endpoint}
      basic_auth {
        username = ${riverValue signal.user}
        password = sys.env("GC_TOKEN")
      }
    }
  '';

  indent =
    n: text:
    concatStringsSep "\n" (
      map (l: if l == "" then l else "${n}${l}") (lib.splitString "\n" (lib.removeSuffix "\n" text))
    );

  mkMetricsBlock =
    cfg:
    let
      extraTargets = map mkScrapeTarget cfg.metrics.extraScrapeTargets;
    in
    ''
      // Metrics
    ''
    + optionalString cfg.metrics.nodeExporter ''
      prometheus.exporter.unix "node" {
        set_collectors = ${riverValue cfg.metrics.nodeExporterCollectors}
      }

      prometheus.scrape "node" {
        targets         = prometheus.exporter.unix.node.targets
        scrape_interval = ${riverValue cfg.metrics.scrapeInterval}
        forward_to      = [prometheus.remote_write.gc.receiver]
      }

    ''
    + optionalString (extraTargets != [ ]) ''
      prometheus.scrape "extra" {
        targets         = ${riverValue extraTargets}
        scrape_interval = ${riverValue cfg.metrics.scrapeInterval}
        forward_to      = [prometheus.remote_write.gc.receiver]
      }

    ''
    + ''
      prometheus.remote_write "gc" {
      ${indent "  " (mkEndpoint cfg.metrics)}
        external_labels = ${riverValue (mkLabels cfg)}
      }
    '';

  mkLogsBlock =
    cfg:
    let
      fileTargets = map mkLogFileTarget cfg.logs.files;
      labels = mkLabels cfg;
    in
    ''
      // Logs
    ''
    + optionalString cfg.logs.journal ''
      loki.relabel "journal" {
        forward_to = []
        rule {
          source_labels = ["__journal__systemd_unit"]
          target_label  = "unit"
        }
        rule {
          source_labels = ["__journal__hostname"]
          target_label  = "host"
        }
      }

      loki.source.journal "journal" {
        forward_to    = [loki.write.gc.receiver]
        labels        = ${riverValue ({ job = "systemd-journal"; } // labels)}
        relabel_rules = loki.relabel.journal.rules
      }

    ''
    + optionalString (fileTargets != [ ]) ''
      local.file_match "files" {
        path_targets = ${riverValue fileTargets}
      }

      loki.source.file "files" {
        targets    = local.file_match.files.targets
        forward_to = [loki.write.gc.receiver]
      }

    ''
    + ''
      loki.write "gc" {
      ${indent "  " (mkEndpoint cfg.logs)}
        external_labels = ${riverValue labels}
      }
    '';

  mkTracesBlock =
    cfg:
    let
      labels = mkLabels cfg;
      # The OTLP exporter has no external_labels setting, so the labels ride
      # along as resource attributes.
      target =
        if labels == { } then
          "otelcol.exporter.otlphttp.gc.input"
        else
          "otelcol.processor.transform.labels.input";
      statement = k: v: "set(resource.attributes[${riverValue k}], ${riverValue v})";
      processor = ''
        otelcol.processor.transform "labels" {
          error_mode = "ignore"
          trace_statements {
            context    = "resource"
            statements = ${riverValue (mapAttrsToList statement labels)}
          }
          output {
            traces = [otelcol.exporter.otlphttp.gc.input]
          }
        }

      '';
    in
    ''
      // Traces (OTLP to Grafana Cloud Tempo)
      otelcol.receiver.otlp "default" {
        grpc {
          endpoint = ${riverValue cfg.traces.otlpGrpcListen}
        }
        http {
          endpoint = ${riverValue cfg.traces.otlpHttpListen}
        }
        output {
          traces = [${target}]
        }
      }

    ''
    + optionalString (labels != { }) processor
    + ''
      otelcol.auth.basic "gc" {
        username = ${riverValue cfg.traces.user}
        password = sys.env("GC_TOKEN")
      }

      otelcol.exporter.otlphttp "gc" {
        client {
          endpoint = ${riverValue cfg.traces.endpoint}
          auth     = otelcol.auth.basic.gc.handler
        }
      }
    '';

  mkProfilesBlock =
    cfg:
    ''
      // Profiles (Pyroscope)
      pyroscope.write "gc" {
      ${indent "  " (mkEndpoint cfg.profiles)}
        external_labels = ${riverValue (mkLabels cfg)}
      }
    ''
    + optionalString cfg.profiles.selfScrape ''

      pyroscope.scrape "self" {
        targets = [
          { __address__ = ${riverValue cfg.profiles.selfScrapeAddress}, service_name = "alloy" },
        ]
        forward_to = [pyroscope.write.gc.receiver]
      }
    '';

  mkSignalEndpoint = what: example: {
    endpoint = mkOption {
      type = types.nullOr types.str;
      default = null;
      inherit example;
      description = "${what} endpoint URL of the Grafana Cloud stack.";
    };
    user = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "1234567";
      description = "Basic-auth username (the instance ID of this signal in the stack).";
    };
  };

  labelsOption = {
    labels = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Additional labels.";
    };
  };
in
{
  # Option tree shared by both modules. `defaults` lets a wrapper change the
  # initial enable state of each signal.
  mkOptions =
    {
      pkgs,
      defaults ? { },
    }:
    let
      d = {
        metricsEnable = true;
        logsEnable = true;
        tracesEnable = false;
        profilesEnable = false;
        nodeExporter = true;
      }
      // defaults;
    in
    {
      enable = mkEnableOption "shipping telemetry to Grafana Cloud via Grafana Alloy";

      package = mkOption {
        type = types.package;
        default = pkgs.grafana-alloy;
        defaultText = lib.literalExpression "pkgs.grafana-alloy";
        description = "Grafana Alloy package to run.";
      };

      environment = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "prod";
        description = "Value for an `env` external label. No label is added when null.";
      };

      environmentFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/grafana-cloud.env";
        description = ''
          Path to a systemd EnvironmentFile that defines `GC_TOKEN`, a
          Grafana Cloud Access Policy token valid for every enabled signal.
          Required when the module is enabled. The file is read at run time
          and never copied to the Nix store.
        '';
      };

      externalLabels = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Extra external labels attached to every signal.";
      };

      extraConfig = mkOption {
        type = types.lines;
        default = "";
        description = "Extra Alloy (River) configuration appended verbatim.";
      };

      metrics = {
        enable = mkOption {
          type = types.bool;
          default = d.metricsEnable;
          description = "Send metrics to Grafana Cloud Prometheus.";
        };
        nodeExporter = mkOption {
          type = types.bool;
          default = d.nodeExporter;
          description = "Enable the built-in `prometheus.exporter.unix` (node exporter).";
        };
        nodeExporterCollectors = mkOption {
          type = types.listOf types.str;
          default = [
            "cpu"
            "diskstats"
            "filesystem"
            "loadavg"
            "meminfo"
            "netdev"
            "netstat"
            "stat"
            "time"
            "uname"
            "vmstat"
          ];
          description = "Collectors enabled on `prometheus.exporter.unix`.";
        };
        scrapeInterval = mkOption {
          type = types.str;
          default = "60s";
          description = "Scrape interval for the built-in scrape jobs.";
        };
        smartctl = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Run the smartctl exporter and scrape it for SMART attributes.
              Honoured by the NixOS module only.
            '';
          };
          listenAddress = mkOption {
            type = types.str;
            default = "127.0.0.1";
            description = "Listen address of the smartctl exporter.";
          };
          port = mkOption {
            type = types.port;
            default = 9633;
            description = "TCP port of the smartctl exporter.";
          };
          devices = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "/dev/sda"
              "/dev/nvme0n1"
            ];
            description = "Devices to monitor. Empty means autodiscover.";
          };
          maxInterval = mkOption {
            type = types.str;
            default = "60s";
            description = "Minimum interval between SMART queries per disk.";
          };
        };
        extraScrapeTargets = mkOption {
          default = [ ];
          description = "Additional static scrape targets.";
          type = types.listOf (
            types.submodule {
              options = {
                address = mkOption {
                  type = types.str;
                  example = "127.0.0.1:9100";
                  description = "host:port of the scrape target.";
                };
                job = mkOption {
                  type = types.str;
                  description = "Prometheus `job` label.";
                };
              }
              // labelsOption;
            }
          );
        };
      }
      // mkSignalEndpoint "Prometheus remote_write" "https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push";

      logs = {
        enable = mkOption {
          type = types.bool;
          default = d.logsEnable;
          description = "Send logs to Grafana Cloud Loki.";
        };
        journal = mkOption {
          type = types.bool;
          default = true;
          description = "Forward systemd journal entries.";
        };
        files = mkOption {
          default = [ ];
          description = "Log files to tail.";
          type = types.listOf (
            types.submodule {
              options = {
                path = mkOption {
                  type = types.str;
                  example = "/var/log/*.log";
                  description = "Glob path to tail.";
                };
              }
              // labelsOption;
            }
          );
        };
      }
      // mkSignalEndpoint "Loki push" "https://logs-prod-012.grafana.net/loki/api/v1/push";

      traces = {
        enable = mkOption {
          type = types.bool;
          default = d.tracesEnable;
          description = "Expose OTLP receivers and forward traces to Grafana Cloud Tempo.";
        };
        otlpGrpcListen = mkOption {
          type = types.str;
          default = "127.0.0.1:4317";
          description = "Listen address of the OTLP gRPC receiver.";
        };
        otlpHttpListen = mkOption {
          type = types.str;
          default = "127.0.0.1:4318";
          description = "Listen address of the OTLP HTTP receiver.";
        };
      }
      // mkSignalEndpoint "OTLP HTTP" "https://otlp-gateway-prod-eu-west-0.grafana.net/otlp";

      profiles = {
        enable = mkOption {
          type = types.bool;
          default = d.profilesEnable;
          description = "Send continuous profiling data to Grafana Cloud Profiles.";
        };
        selfScrape = mkOption {
          type = types.bool;
          default = true;
          description = "Scrape Alloy's own pprof endpoints.";
        };
        selfScrapeAddress = mkOption {
          type = types.str;
          default = "127.0.0.1:12345";
          description = "Address of Alloy's HTTP server, scraped when `selfScrape` is set.";
        };
      }
      // mkSignalEndpoint "Pyroscope push" "https://profiles-prod-001.grafana.net";
    };

  # Render the full config.alloy from a resolved option tree.
  mkAlloyConfig =
    cfg:
    concatStringsSep "\n" (
      [ "// Generated by the grafanaCloud module. Do not edit by hand." ]
      ++ optionals cfg.metrics.enable [ (mkMetricsBlock cfg) ]
      ++ optionals cfg.logs.enable [ (mkLogsBlock cfg) ]
      ++ optionals cfg.traces.enable [ (mkTracesBlock cfg) ]
      ++ optionals cfg.profiles.enable [ (mkProfilesBlock cfg) ]
      ++ optional (cfg.extraConfig != "") cfg.extraConfig
    );

  # Assertions verifying that every enabled signal has its endpoint and user
  # and that the token file is set. `prefix` names the option path in messages.
  mkAssertions =
    prefix: cfg:
    let
      signalOk = s: !cfg.${s}.enable || (cfg.${s}.endpoint != null && cfg.${s}.user != null);
      signalMsg = s: "${prefix}.${s}.{endpoint,user} must be set when ${prefix}.${s}.enable = true.";
    in
    [
      {
        assertion = cfg.environmentFile != null;
        message = "${prefix}.environmentFile must point at a file defining GC_TOKEN.";
      }
      {
        assertion = signalOk "metrics";
        message = signalMsg "metrics";
      }
      {
        assertion = signalOk "logs";
        message = signalMsg "logs";
      }
      {
        assertion = signalOk "traces";
        message = signalMsg "traces";
      }
      {
        assertion = signalOk "profiles";
        message = signalMsg "profiles";
      }
      {
        assertion = !cfg.logs.enable || cfg.logs.journal || cfg.logs.files != [ ];
        message = "${prefix}.logs.enable is true but neither `journal` nor `files` is set; nothing would be shipped.";
      }
    ];
}
