# Open Code Review (`ocr`), an LLM code-review CLI. It reads one user config,
# ~/.opencodereview/config.json, which `ocr config set` and its TUI rewrite in
# place, so this module merges `settings` into that file on activation
# instead of owning it: managed keys win, everything else is kept. The last
# applied settings are saved beside the config (.hm-settings.json) so a key
# dropped from `settings` is removed on the next activation. Keys set with
# `ocr config set` are never in that copy and survive. Without a copy nothing
# is pruned. An object that pruning leaves empty is removed too.
#
# `ocr` is a wrapper that sets the OTEL_* variables (the OTLP protocol and
# headers have no config key), reading the headers file at run time
# (lib.openCodeReview.mkWrapper).
{
  config,
  lib,
  pkgs,
  extraLib,
  ...
}:
let
  cfg = config.programs.open-code-review;
  configFile = "${config.home.homeDirectory}/.opencodereview/config.json";
  stateFile = "${config.home.homeDirectory}/.opencodereview/.hm-settings.json";
  settingsFile = (pkgs.formats.json { }).generate "open-code-review-settings.json" cfg.settings;

  # Arrays count as leaves, so a dropped list key is removed whole.
  pruneFilter = pkgs.writeText "ocr-prune.jq" ''
    def leaves($pre): to_entries[] | . as {$key, $value}
      | if ($value | type) == "object" then $value | leaves($pre + [$key])
        else $pre + [$key] end;
    def drop_empty($p):
      if ($p | length) > 0 and getpath($p) == {} then delpaths([$p]) | drop_empty($p[:-1])
      else . end;
    ([$old | leaves([])] - [$new[0] | leaves([])]) as $gone
    | reduce $gone[] as $p (.; delpaths([$p]) | drop_empty($p[:-1]))
    | . * $new[0]
  '';

  wrapper = extraLib.openCodeReview.mkWrapper {
    inherit pkgs;
    inherit (cfg) package telemetry;
  };
in
{
  options.programs.open-code-review = {
    enable = lib.mkEnableOption "Open Code Review, the `ocr` code-review CLI";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.llm-agents.open-code-review or null;
      defaultText = lib.literalExpression "pkgs.llm-agents.open-code-review";
      description = ''
        The open-code-review package. Comes from numtide/llm-agents.nix: apply its
        `overlays.shared-nixpkgs` or set this option.
      '';
    };

    installWrapper = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to install the `ocr` wrapper in the Home Manager profile. Turn it off
        when the wrapper comes from another profile; build it there with
        `lib.openCodeReview.mkWrapper`. The settings merge and the viewer unit stay.
      '';
    };

    settings = lib.mkOption {
      inherit (pkgs.formats.json { }) type;
      default = { };
      example = lib.literalExpression ''
        {
          provider = "local";
          model = "qwen3-coder";
          custom_providers.local = {
            url = "http://127.0.0.1:8080/v1";
            protocol = "openai";
            api_key = "local";
          };
        }
      '';
      description = ''
        Keys merged into {file}`~/.opencodereview/config.json` on activation
        (see the upstream configuration docs). Literal API keys land in the
        Nix store; use `api_key_cmd` for real secrets.
      '';
    };

    telemetry = {
      enable = lib.mkEnableOption "OTLP/HTTP trace and metric export";

      metrics.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to export metrics. Turn it off for backends that only ingest
          traces; it sets `OTEL_METRICS_EXPORTER=none`. The package must honor
          that variable (stock OCR 1.13.3 does not).
        '';
      };

      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "http://127.0.0.1:6006";
        description = "OTLP/HTTP base URL; `/v1/traces` and `/v1/metrics` are appended.";
      };

      headersFile = lib.mkOption {
        type = lib.types.str;
        description = ''
          JSON object of HTTP headers for the exporter, read at every run,
          for example a file holding an API key header.
        '';
      };

      resourceAttributes = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = {
          "openinference.project.name" = "open-code-review";
        };
        description = ''
          OpenTelemetry resource attributes (`OTEL_RESOURCE_ATTRIBUTES`); Some backends
          take the project from `openinference.project.name`.
        '';
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        default = "open-code-review";
        description = "OpenTelemetry `service.name`.";
      };
    };

    viewer = {
      enable = lib.mkEnableOption "the session viewer (`ocr viewer`) as a user service";

      port = lib.mkOption {
        type = lib.types.port;
        default = 5483;
        description = "Loopback port of the viewer.";
      };

      allowedHosts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "ocr.localhost" ];
        description = ''
          Extra Host headers the viewer accepts besides loopback
          (`OCR_VIEWER_ALLOWED_HOSTS`), for a reverse proxy in front of it.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.package != null;
            message = "programs.open-code-review.package is unset: apply the overlays.shared-nixpkgs overlay of numtide/llm-agents.nix (it provides pkgs.llm-agents.open-code-review) or set the option.";
          }
        ];
      }
      (lib.mkIf (cfg.package != null) {
        home.packages = lib.optional cfg.installWrapper wrapper;

        home.activation.openCodeReviewConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          conf=${lib.escapeShellArg configFile}
          state=${lib.escapeShellArg stateFile}
          if [ -e "$state" ]${lib.optionalString (cfg.settings != { }) " || true"}; then
            run mkdir -p "$(dirname "$conf")"
            if [ -s "$conf" ]; then current=$(cat "$conf"); else current='{}'; fi
            if [ -s "$state" ]; then old=$(cat "$state"); else old='{}'; fi
            merged=$(printf '%s' "$current" | ${lib.getExe pkgs.jq} \
              --argjson old "$old" --slurpfile new ${settingsFile} -f ${pruneFilter})
            if [ -z "''${DRY_RUN:-}" ]; then
              ( umask 077
                printf '%s\n' "$merged" > "$conf.tmp"
                cp ${settingsFile} "$state.tmp" && chmod 600 "$state.tmp" ) \
                && mv "$conf.tmp" "$conf" && mv "$state.tmp" "$state"
            fi
          fi
        '';

        systemd.user.services.ocr-viewer = lib.mkIf cfg.viewer.enable {
          Unit.Description = "Open Code Review session viewer";
          Service = {
            ExecStart = "${lib.getExe cfg.package} viewer --addr 127.0.0.1:${toString cfg.viewer.port} --open=never";
            Environment = lib.optional (
              cfg.viewer.allowedHosts != [ ]
            ) "OCR_VIEWER_ALLOWED_HOSTS=${lib.concatStringsSep "," cfg.viewer.allowedHosts}";
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
