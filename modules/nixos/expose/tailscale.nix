# Tailscale backend: applies the entries as `tailscale serve` (tailnet only)
# or `tailscale funnel` (public) mappings from a oneshot unit, either on a
# port of this node or on a Tailscale Service (`svc:<name>`, its own address
# and DNS name).
#
# nixpkgs' services.tailscale.serve only covers Tailscale Services, so this
# drives the CLI. The unit resets serve and funnel state before applying (so
# removed entries are torn down), which would also wipe
# services.tailscale.serve: hence the assertion against using both.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  top = config.services.expose;
  cfg = top.tailscale;

  entries = lib.filter (e: e.enable && e.tailscale.enable) (
    lib.mapAttrsToList (name: e: e // { inherit name; }) top.services
  );

  # Funnel only listens on these ports; tailscaled rejects any other at apply
  # time, halfway through the reset.
  funnelPorts = [
    443
    8443
    10000
  ];

  render =
    e:
    let
      t = e.tailscale;
      verb = if t.funnel then "funnel" else "serve";
      service = lib.optionalString (t.service != null) "--service=svc:${t.service} ";
    in
    "tailscale ${verb} --bg ${service}--${t.protocol}=${toString t.port} ${lib.escapeShellArg e.upstream}";

  serviceEntries = lib.filter (e: e.tailscale.service != null) entries;
  nodeEntries = lib.filter (e: e.tailscale.service == null) entries;

  applyScript = pkgs.writeShellApplication {
    name = "tailscale-serve-expose";
    runtimeInputs = [
      config.services.tailscale.package
      pkgs.jq
    ];
    text = ''
      # tailscaled can accept commands before it has a netmap; serve then
      # fails with "netMap is nil". Wait for the backend to be Running.
      for _ in $(seq 1 30); do
        state=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // ""')
        [ "$state" = "Running" ] && break
        sleep 1
      done

      tailscale serve reset
      tailscale funnel reset

      ${lib.concatMapStringsSep "\n" render nodeEntries}

      ${lib.optionalString (serviceEntries != [ ]) ''
        # Only tagged nodes may host a Tailscale Service, and a failed serve
        # fails the activation: warn and skip until the node is tagged.
        if tailscale status --json | jq -e '(.Self.Tags // []) | length > 0' >/dev/null; then
          ${lib.concatMapStringsSep "\n  " render serviceEntries}
        else
          echo "tailscale-serve-expose: this node is not tagged; skipping ${
            lib.concatMapStringsSep ", " (e: "svc:${e.tailscale.service}") serviceEntries
          }" >&2
        fi
      ''}
    '';
  };

  # The `--bg` mappings (and a public Funnel) outlive this unit, so clear
  # them on stop. switch-to-configuration stops a removed unit with the OLD
  # ExecStop, hence the managed services are baked in. Best effort.
  stopScript = pkgs.writeShellApplication {
    name = "tailscale-serve-expose-stop";
    runtimeInputs = [ config.services.tailscale.package ];
    text = ''
      tailscale funnel reset || true
      tailscale serve reset || true
      ${lib.concatMapStringsSep "\n" (
        e: "tailscale serve clear svc:${e.tailscale.service} || true"
      ) serviceEntries}
    '';
  };

  # Port suffix only where it differs from the scheme's default.
  url =
    e:
    let
      t = e.tailscale;
      host = "${if t.service != null then t.service else cfg.nodeName}.${cfg.domain}";
      defaultPort = (t.protocol == "https" && t.port == 443) || (t.protocol == "http" && t.port == 80);
      port = lib.optionalString (!defaultPort) ":${toString t.port}";
    in
    if t.protocol == "tcp" then
      "tcp://${host}:${toString t.port}"
    else
      "${t.protocol}://${host}${port}${e.path}";

  listener = e: "${toString e.tailscale.service}:${toString e.tailscale.port}";
  clashes = lib.filterAttrs (_: es: lib.length es > 1) (lib.groupBy listener entries);

  # services.tailscale.serve only exists in newer nixpkgs.
  nixpkgsServe = options.services.tailscale ? serve && config.services.tailscale.serve.enable;
in
{
  options.services.expose = {
    tailscale = {
      enable = lib.mkEnableOption "publishing services.expose entries with tailscale serve";

      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "tail0123.example";
        description = ''
          The tailnet's MagicDNS suffix. Only used to fill in `urls` (and so
          the landing page); null leaves the tailnet URLs out.
        '';
      };

      nodeName = mkOption {
        type = types.str;
        default = config.networking.hostName;
        defaultText = lib.literalExpression "config.networking.hostName";
        description = "This node's MagicDNS name, for the URLs of node-port entries.";
      };
    };

    services = mkOption {
      type = types.attrsOf (
        types.submodule (
          { config, ... }:
          {
            options.tailscale = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether the Tailscale backend publishes this entry, once
                  `services.expose.tailscale.enable` is set.
                '';
              };

              port = mkOption {
                type = types.port;
                default = 443;
                description = ''
                  Port the entry listens on: on this node's tailnet address,
                  or on the Tailscale Service's own address when `service` is
                  set.
                '';
              };

              protocol = mkOption {
                type = types.enum [
                  "https"
                  "http"
                  "tcp"
                ];
                default = "https";
                description = ''
                  Listener protocol. `https` terminates TLS with the tailnet
                  certificate; `tcp` forwards raw TCP.
                '';
              };

              funnel = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Publish on the public internet with Tailscale Funnel instead
                  of the tailnet only. The tailnet policy must allow funnel
                  for this node.
                '';
              };

              service = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "jellyfin";
                description = ''
                  Publish as the Tailscale Service `svc:<service>` instead of
                  on a port of this node. The node must be tagged, and the
                  tailnet policy must let it host the service (or approve it
                  automatically).
                '';
              };
            };

            config.urls = lib.mkIf (
              top.tailscale.enable && cfg.domain != null && config.enable && config.tailscale.enable
            ) { tailscale = url config; };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "services.expose.tailscale.enable requires services.tailscale.enable.";
      }
      {
        assertion = !nixpkgsServe;
        message = ''
          services.expose.tailscale and services.tailscale.serve both manage
          tailscale serve state, and each run of one resets the other's.
          Enable only one.
        '';
      }
      {
        assertion = clashes == { };
        message = ''
          services.expose.services: several entries use the same tailscale
          listener: ${
            lib.concatStringsSep "; " (
              lib.mapAttrsToList (_: es: lib.concatMapStringsSep ", " (e: e.name) es) clashes
            )
          }.
        '';
      }
    ]
    ++ lib.concatMap (e: [
      {
        assertion = !(e.tailscale.funnel && e.tailscale.service != null);
        message = ''
          services.expose.services.${e.name}: funnel cannot be combined with
          tailscale.service; tailscale rejects `funnel --service`. Funnel
          publishes a port of this node only.
        '';
      }
      {
        assertion = !(e.tailscale.funnel && e.tailscale.protocol == "http");
        message = "services.expose.services.${e.name}: funnel accepts https or tcp, not http.";
      }
      {
        assertion = !e.tailscale.funnel || lib.elem e.tailscale.port funnelPorts;
        message = ''
          services.expose.services.${e.name}: funnel listens only on ports
          ${lib.concatMapStringsSep ", " toString funnelPorts} (got ${toString e.tailscale.port}).
        '';
      }
      {
        assertion =
          e.tailscale.service == null
          || builtins.match "[a-z0-9]([a-z0-9-]*[a-z0-9])?" e.tailscale.service != null;
        message = ''
          services.expose.services.${e.name}: tailscale.service must be a DNS
          label (lowercase letters, digits and hyphens), without the svc: prefix.
        '';
      }
    ]) entries;

    systemd.services.tailscale-serve-expose = {
      description = "Apply services.expose with tailscale serve";
      after = [
        "tailscaled.service"
        "tailscaled-autoconnect.service"
        "tailscaled-set.service"
        "network-online.target"
      ];
      wants = [
        "tailscaled.service"
        "network-online.target"
      ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        applyScript
        stopScript
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe applyScript;
        ExecStop = lib.getExe stopScript;
      };
    };
  };
}
