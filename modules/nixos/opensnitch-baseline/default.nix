# Declarative OpenSnitch allow rules for traffic every host makes: loopback,
# the system network services, and Nix substituters/remote builders.
#
# Rules match exact store paths, not a name regexp: any user can add
# /nix/store/<hash>-google-chrome-*/... through the daemon, so a pattern would
# let an arbitrary binary inherit the allow.
#
# Declared rules are read-only store symlinks; popup-created rules are regular
# files next to them.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.opensnitchBaseline;

  simple = operand: data: {
    type = "simple";
    sensitive = false;
    inherit operand data;
  };

  # One-of match on exact strings, as an anchored alternation.
  anyOf = operand: values: {
    type = "regexp";
    sensitive = false;
    inherit operand;
    data = "^(${lib.concatMapStringsSep "|" lib.escapeRegex values})$";
  };

  allowRule = name: operator: extra: {
    inherit name;
    value = {
      inherit name operator;
      enabled = true;
      # opensnitchd warns on every rule match when the date is empty; a fixed
      # value keeps the rule files reproducible.
      created = "2026-10-13T00:00:00Z";
      action = "allow";
      duration = "always";
    }
    // extra;
  };

  # Host of a substituter / upstream / builder URL; s3:// takes its endpoint.
  # ncro (an optional Nix cache router) is read only when its module is imported.
  ncro = config.services.ncro or { };

  urlHost =
    url:
    let
      s3 = builtins.match "s3://[^?]*\\?(.*&)?endpoint=([^&]+).*" url;
      generic = builtins.match "[a-z0-9+-]+://([^/:?]+).*" url;
    in
    if s3 != null then
      lib.elemAt s3 1
    else if generic != null then
      lib.head generic
    else
      url;

  nixHosts = lib.filter (h: h != "localhost" && h != "127.0.0.1") (
    lib.unique (
      map urlHost (
        config.nix.settings.substituters ++ map (u: u.url or u) (ncro.settings.upstreams or [ ])
      )
      ++ map (m: m.hostName) config.nix.buildMachines
    )
  );
in
{
  options.services.opensnitchBaseline = {
    enable = lib.mkEnableOption "baseline OpenSnitch allow rules (loopback, system services, Nix caches)";

    allowPrograms = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''{ slack = "''${pkgs.slack}/lib/slack/slack"; }'';
      description = ''
        Executables allowed to connect anywhere, keyed by rule name. Use the
        path the kernel runs (the unwrapped binary for wrapped programs).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.opensnitch.enable = true;

    # Applied when no UI client answers a prompt. Matches upstream's default;
    # pinned against drift.
    services.opensnitch.settings.DefaultAction = "allow";

    services.opensnitchBaseline.allowPrograms = {
      nsncd = lib.mkIf config.services.nscd.enableNsncd "${pkgs.nsncd}/bin/nsncd";
      systemd-timesyncd = lib.mkIf config.services.timesyncd.enable "${config.systemd.package}/lib/systemd/systemd-timesyncd";
      systemd-resolved = lib.mkIf config.services.resolved.enable "${config.systemd.package}/lib/systemd/systemd-resolved";
      avahi-daemon = lib.mkIf config.services.avahi.enable "${config.services.avahi.package}/bin/avahi-daemon";
      cups-browsed = lib.mkIf config.services.printing.browsed.enable "${config.services.printing.browsed.package}/bin/cups-browsed";
      ncro = lib.mkIf (ncro.enable or false) "${ncro.package}/bin/ncro";
    };

    # opensnitchd warns when this is missing or empty; the key is "tasks".
    environment.etc."opensnitchd/tasks/tasks.json".text = builtins.toJSON { tasks = [ ]; };

    services.opensnitch.rules = lib.listToAttrs (
      [
        (allowRule "000-allow-loopback" (simple "dest.network" "127.0.0.0/8" // { type = "network"; }) {
          precedence = true;
          nolog = true;
        })
        (allowRule "000-allow-loopback6" (simple "dest.ip" "::1") {
          precedence = true;
          nolog = true;
        })
        (allowRule "allow-nix-caches" {
          type = "list";
          operand = "list";
          sensitive = false;
          list = [
            # nix-daemon runs as bin/nix; it spawns ssh for ssh-ng:// builders.
            (anyOf "process.path" [
              "${config.nix.package}/bin/nix"
              "${config.programs.ssh.package}/bin/ssh"
            ])
            (anyOf "dest.host" nixHosts)
          ];
        } { })
      ]
      ++ lib.mapAttrsToList (
        name: path: allowRule "allow-${name}" (simple "process.path" path) { }
      ) cfg.allowPrograms
    );
  };
}
