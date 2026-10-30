# agentsview, a local web UI over the session files of Claude Code, Codex,
# OpenCode and Hermes. It reads those files and keeps its own SQLite index
# under dataDir; it installs no hooks and never writes to the session roots.
# The unit mounts the session roots read-only.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agentsview;
  home = config.home.homeDirectory;
in
{
  options.services.agentsview = {
    enable = lib.mkEnableOption "the agentsview session browser as a user service";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.llm-agents.agentsview or null;
      defaultText = lib.literalExpression "pkgs.llm-agents.agentsview";
      description = ''
        The agentsview package. Comes from numtide/llm-agents.nix: apply its
        `overlays.shared-nixpkgs` or set this option.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Loopback port of the web UI.";
    };

    publicOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "http://agentsview.localhost" ];
      description = ''
        Extra origins that pass the Host and Origin checks (`--public-origin`),
        for a reverse proxy in front of the UI.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.agentsview";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.agentsview"'';
      description = "Directory of the SQLite index; agentsview creates it.";
    };

    readOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${home}/.claude"
        "${home}/.codex"
        "${home}/.local/share/opencode"
        "${home}/.hermes"
      ];
      defaultText = lib.literalExpression ''
        map (p: "''${config.home.homeDirectory}/" + p) [
          ".claude"
          ".codex"
          ".local/share/opencode"
          ".hermes"
        ]
      '';
      description = "Session roots the unit sees read-only.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.package != null;
            message = "services.agentsview.package is unset: apply the overlays.shared-nixpkgs overlay of numtide/llm-agents.nix (it provides pkgs.llm-agents.agentsview) or set the option.";
          }
        ];
      }
      (lib.mkIf (cfg.package != null) {
        home.packages = [ cfg.package ];

        systemd.user.services.agentsview = {
          Unit.Description = "agentsview session browser";
          Service = {
            ExecStart = "${lib.getExe cfg.package} serve --host 127.0.0.1 --port ${toString cfg.port} --no-browser${
              lib.optionalString (
                cfg.publicOrigins != [ ]
              ) " --public-origin ${lib.escapeShellArg (lib.concatStringsSep "," cfg.publicOrigins)}"
            }";
            Environment = [
              "AGENTSVIEW_DATA_DIR=${cfg.dataDir}"
              "AGENTSVIEW_DISABLE_UPDATE_CHECK=1"
              # The PostHog reporter defaults to on; these opt out.
              "AGENTSVIEW_TELEMETRY_ENABLED=0"
              "DO_NOT_TRACK=1"
            ];
            # Missing roots (a tool never used) must not fail the unit, hence the "-".
            ReadOnlyPaths = map (p: "-${p}") cfg.readOnlyPaths;
            PrivateTmp = true;
            NoNewPrivileges = true;
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
            ];
            Restart = "on-failure";
            RestartSec = "5s";
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
