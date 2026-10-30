# OpenViking server, a context filesystem / "agent-native context database"
# for AI agents. Runs `openviking-server` as a systemd service listening on
# :1933, the port the `ov` CLI talks to.
#
# Inert until `services.openviking-server.enable` is set. The server needs an
# `ov.conf` describing embedding + VLM providers (and their API keys); point
# `configFile` at one that a secret manager renders at run time, so keys never
# land in the Nix store.
{
  config,
  lib,
  options,
  extraPkgs,
  extraLib,
  ...
}:
let
  ov = extraLib.openviking;
  cfg = config.services.openviking-server;

  stateDir = "/var/lib/openviking";
in
{
  options.services.openviking-server = (ov.commonServiceOptions { inherit extraPkgs; }) // {
    enable = lib.mkEnableOption "the OpenViking context-filesystem server";

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `port` in the host firewall. Off by default.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "openviking";
      description = ''
        System group that owns secrets the server must read. Because the
        unit uses `DynamicUser`, secrets (e.g. `configFile`) can't be owned
        by a static user; instead make them group-owned by this group with
        a group-readable mode (`0440`). The dynamic user is added to the
        group via `SupplementaryGroups`.
      '';
    };

    exposeViaTailscale = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Publish the server as the Tailscale Service `svc:openviking` (TLS on
        443) through the `expose` module of this repository, which must be
        imported, with `services.expose.tailscale.enable` set.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = !cfg.exposeViaTailscale || options.services ? expose;
          message = ''
            services.openviking-server.exposeViaTailscale needs the expose
            module (services.expose), and it is not imported.
          '';
        }
        {
          assertion =
            !cfg.exposeViaTailscale || !(options.services ? expose) || config.services.expose.tailscale.enable;
          message = ''
            services.openviking-server.exposeViaTailscale requires
            services.expose.tailscale.enable.
          '';
        }
      ];

      # DynamicUser can't own files by a static user, so secrets are shared via
      # this group; the dynamic uid joins it through SupplementaryGroups below.
      users.groups.${cfg.group} = { };

      systemd.services.openviking-server = {
        description = "OpenViking context-filesystem server";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];

        environment = {
          HOME = stateDir;
          # Bot mode (--with-bot / server.with_bot) locates the vikingbot
          # gateway child via shutil.which("vikingbot"); keep the standard
          # system PATH entries so we prepend rather than replace them.
          PATH = "${lib.getBin cfg.package}/bin:/run/wrappers/bin:/run/current-system/sw/bin";
        }
        // cfg.environment;

        serviceConfig = {
          ExecStart = lib.escapeShellArgs (
            ov.mkExecArgs {
              inherit (cfg)
                package
                host
                port
                configFile
                ;
            }
          );
          EnvironmentFile = cfg.environmentFiles;
          WorkingDirectory = stateDir;
          # systemd creates and chowns /var/lib/openviking for the dynamic
          # user, and adds it to the unit's read-write paths automatically.
          StateDirectory = "openviking";
          DynamicUser = true;
          # Join the shared group so the dynamic uid can read group-owned
          # secrets (e.g. a rendered configFile).
          SupplementaryGroups = [ cfg.group ];
          Restart = "on-failure";
          RestartSec = 5;

          # Hardening: the server only needs its own state dir.
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    })

    # Only when the expose module is imported.
    (lib.optionalAttrs (options.services ? expose) {
      services.expose.services = lib.mkIf (cfg.enable && cfg.exposeViaTailscale) {
        openviking = {
          title = "OpenViking";
          upstream = "http://127.0.0.1:${toString cfg.port}";
          tailscale.service = "openviking";
        };
      };
    })
  ];
}
