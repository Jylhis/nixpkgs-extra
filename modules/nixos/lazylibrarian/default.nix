# LazyLibrarian as a systemd service: the web UI on `port`, with its
# database, config.ini, cache and logs in `dataDir`.
#
# Inert until `services.lazylibrarian.enable` is set. Everything else
# (providers, download clients, library folders, credentials) is configured
# in the web UI and kept in `dataDir`/config.ini; the library folders it
# writes to must be writable by `user`.
{
  config,
  lib,
  extraPkgs,
  ...
}:
let
  cfg = config.services.lazylibrarian;

  defaultDataDir = "/var/lib/lazylibrarian";
in
{
  options.services.lazylibrarian = {
    enable = lib.mkEnableOption "LazyLibrarian, an ebook, audiobook and magazine downloader";

    package = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.lazylibrarian;
      defaultText = lib.literalExpression "pkgs.lazylibrarian";
      description = "The LazyLibrarian package to run.";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = defaultDataDir;
      description = "Directory for the database, config.ini, cache and logs.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5299;
      description = "Port of the web UI. Overrides the port saved in config.ini.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `port` in the host firewall.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "lazylibrarian";
      description = "User the service runs as. Created only when left at the default.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "lazylibrarian";
      description = "Group the service runs as. Created only when left at the default.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--loglevel"
        "2"
      ];
      description = "Extra command-line arguments for LazyLibrarian.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.lazylibrarian = {
      description = "LazyLibrarian";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--nolaunch"
            "--datadir"
            cfg.dataDir
            "--port"
            (toString cfg.port)
          ]
          ++ cfg.extraArgs
        );
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = 5;

        # systemd creates and chowns the default directory; a custom one is
        # created by tmpfiles below and made writable here.
        StateDirectory = lib.mkIf (cfg.dataDir == defaultDataDir) "lazylibrarian";
        ReadWritePaths = lib.mkIf (cfg.dataDir != defaultDataDir) [ cfg.dataDir ];

        # Library and download folders live anywhere, so the rest of the
        # file system stays writable for `user`; /usr, /boot and /etc do not.
        ProtectSystem = "full";
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.tmpfiles.settings.lazylibrarian = lib.mkIf (cfg.dataDir != defaultDataDir) {
      ${cfg.dataDir}.d = {
        inherit (cfg) user group;
        mode = "0750";
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    users.users = lib.mkIf (cfg.user == "lazylibrarian") {
      lazylibrarian = {
        isSystemUser = true;
        inherit (cfg) group;
        home = cfg.dataDir;
      };
    };

    users.groups = lib.mkIf (cfg.group == "lazylibrarian") { lazylibrarian = { }; };
  };
}
