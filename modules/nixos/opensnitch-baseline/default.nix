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

  # Every set field narrows the match (the list operator ANDs its members).
  connectionRule =
    name: c:
    let
      hostPatterns = map lib.escapeRegex c.hosts ++ map (d: "(.+\\.)?${lib.escapeRegex d}") c.domains;
    in
    allowRule "${c.action}-${name}" {
      type = "list";
      operand = "list";
      sensitive = false;
      list = [
        (anyOf "process.path" c.programs)
      ]
      ++ lib.optional (hostPatterns != [ ]) {
        type = "regexp";
        sensitive = false;
        operand = "dest.host";
        data = "^(${lib.concatStringsSep "|" hostPatterns})$";
      }
      ++ lib.optional (c.network != null) (simple "dest.network" c.network // { type = "network"; })
      ++ lib.optional (c.ports != [ ]) (anyOf "dest.port" (map toString c.ports))
      ++ lib.optional (c.users != [ ]) (anyOf "user.id" (map toString c.users));
    } { inherit (c) action; };

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

  # The curl fetchurl runs: a curlMinimal override that only fetchurl's own
  # arguments name, so read it back from a throwaway fetchurl derivation.
  # nativeBuildInputs holds the selected dev output, so take .bin directly.
  fetchurlCurl =
    (lib.head
      (pkgs.fetchurl {
        url = "https://example.invalid/";
        hash = lib.fakeHash;
      }).nativeBuildInputs
    ).bin;
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

    connections = lib.mkOption {
      default = { };
      example = lib.literalExpression ''
        {
          gh = {
            programs = [ "''${pkgs.gh}/bin/.gh-wrapped" ];
            hosts = [ "github.com" "api.github.com" ];
            ports = [ 443 ];
          };
        }
      '';
      description = ''
        Rules for executables limited to some destinations, keyed by rule
        name. Every non-empty field must match. Paths follow the same rule as
        {option}`allowPrograms`.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            action = lib.mkOption {
              type = lib.types.enum [
                "allow"
                "deny"
              ];
              default = "allow";
              description = "What to do with a matching connection.";
            };
            programs = lib.mkOption {
              type = lib.types.nonEmptyListOf lib.types.str;
              description = "Executable paths the rule applies to.";
            };
            hosts = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Exact destination host names.";
            };
            domains = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Destination domains, matching the name and every subdomain.";
            };
            network = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              example = "100.64.0.0/10";
              description = "Destination network in CIDR notation.";
            };
            ports = lib.mkOption {
              type = lib.types.listOf lib.types.port;
              default = [ ];
              description = "Destination ports.";
            };
            users = lib.mkOption {
              type = lib.types.listOf lib.types.int;
              default = [ ];
              description = "UIDs of the connecting process.";
            };
          };
        }
      );
    };

    nixHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      description = "Hosts of the Nix substituters, ncro upstreams and remote builders.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.opensnitch.enable = true;

    # Applied when no UI client answers a prompt. Matches upstream's default;
    # pinned against drift.
    services.opensnitch.settings.DefaultAction = "allow";

    services.opensnitchBaseline = {
      inherit nixHosts;

      allowPrograms = {
        nsncd = lib.mkIf config.services.nscd.enableNsncd "${pkgs.nsncd}/bin/nsncd";
        systemd-timesyncd = lib.mkIf config.services.timesyncd.enable "${config.systemd.package}/lib/systemd/systemd-timesyncd";
        systemd-resolved = lib.mkIf config.services.resolved.enable "${config.systemd.package}/lib/systemd/systemd-resolved";
        avahi-daemon = lib.mkIf config.services.avahi.enable "${config.services.avahi.package}/bin/avahi-daemon";
        cups-browsed = lib.mkIf config.services.printing.browsed.enable "${config.services.printing.browsed.package}/bin/cups-browsed";
        ncro = lib.mkIf (ncro.enable or false) "${ncro.package}/bin/ncro";
      };

      connections = {
        # Flake inputs are fetched by the evaluating nix process, not the
        # daemon; the registry resolves indirect refs like nixpkgs#hello.
        nix-fetch = {
          programs = [ "${config.nix.package}/bin/nix" ];
          hosts = [
            "github.com"
            "api.github.com"
            "codeload.github.com"
            "channels.nixos.org"
          ];
          ports = [ 443 ];
        };
        # Fixed-output builds fetch from whatever host a source names, so
        # only the build users and the web ports narrow them.
        nix-fod-fetchers = {
          programs = [
            "${pkgs.gitMinimal}/libexec/git-core/git-remote-http"
            "${fetchurlCurl}/bin/curl"
          ];
          users = lib.genList (i: config.ids.uids.nixbld + 1 + i) config.nix.nrBuildUsers;
          ports = [
            80
            443
          ];
        };
      };
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
      ++ lib.mapAttrsToList connectionRule cfg.connections
    );
  };
}
