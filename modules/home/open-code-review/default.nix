# Open Code Review (`ocr`), an LLM code-review CLI. It reads one user config,
# ~/.opencodereview/config.json, which `ocr config set` and its TUI rewrite in
# place, so this module merges `settings` into that file on activation
# instead of owning it: managed keys win, everything else is kept. A key
# dropped from `settings` stays in the file until `ocr config unset`.
#
# `ocr` is a wrapper that sets the OTEL_* variables (the OTLP protocol and
# headers have no config key), reading the headers file at run time.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.open-code-review;
  configFile = "${config.home.homeDirectory}/.opencodereview/config.json";
  settingsFile = (pkgs.formats.json { }).generate "open-code-review-settings.json" cfg.settings;

  # Without a complete provider in the config file, OCR falls back to Claude
  # Code's ANTHROPIC_* variables. Those credentials are for the Claude Code
  # harness only, so the wrapper drops them and OCR fails instead.
  resourceAttributes = lib.concatStringsSep "," (
    lib.mapAttrsToList (k: v: "${k}=${v}") cfg.telemetry.resourceAttributes
  );

  # A missing or unreadable headers file (the backend not started yet) runs the
  # review without telemetry rather than failing it.
  wrapper = pkgs.writeShellScriptBin "ocr" (
    ''
      unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL
    ''
    + lib.optionalString cfg.telemetry.enable ''
      if headers=$(${lib.getExe pkgs.jq} -r \
          'to_entries | map("\(.key)=\(.value | @uri)") | join(",")' \
          ${lib.escapeShellArg cfg.telemetry.headersFile} 2>/dev/null); then
        export OCR_ENABLE_TELEMETRY=1
        export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
        export OTEL_EXPORTER_OTLP_ENDPOINT=${lib.escapeShellArg cfg.telemetry.endpoint}
        export OTEL_EXPORTER_OTLP_HEADERS="$headers"
        export OTEL_SERVICE_NAME=${lib.escapeShellArg cfg.telemetry.serviceName}
        ${lib.optionalString (cfg.telemetry.resourceAttributes != { }) ''
          export OTEL_RESOURCE_ATTRIBUTES=${lib.escapeShellArg resourceAttributes}
        ''}
      fi
    ''
    + ''
      exec ${lib.getExe cfg.package} "$@"
    ''
  );
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
        home.packages = [ wrapper ];

        home.activation.openCodeReviewConfig = lib.mkIf (cfg.settings != { }) (
          lib.hm.dag.entryAfter [ "writeBoundary" ] ''
            conf=${lib.escapeShellArg configFile}
            run mkdir -p "$(dirname "$conf")"
            if [ -s "$conf" ]; then current=$(cat "$conf"); else current='{}'; fi
            merged=$(printf '%s' "$current" | ${lib.getExe pkgs.jq} --slurpfile s ${settingsFile} '. * $s[0]')
            if [ -z "''${DRY_RUN:-}" ]; then
              ( umask 077; printf '%s\n' "$merged" > "$conf.tmp" ) && mv "$conf.tmp" "$conf"
            fi
          ''
        );

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
