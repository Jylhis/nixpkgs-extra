# Cloudflare Tunnel backend: entries that set `cloudflare.enable` become
# ingress rules (hostname -> upstream) of one tunnel run by nixpkgs'
# services.cloudflared. cloudflared only connects outbound, so no inbound
# port opens. The tunnel, its DNS records and any Cloudflare Access
# application in front of a hostname are created on the Cloudflare side;
# this only routes.
#
# A tunnel hostname without an Access application is open to the whole
# internet. `cloudflare.access = false` records that a hostname is meant to be
# public, and the build warns about each one.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  top = config.services.expose;
  cfg = top.cloudflare;

  entries = lib.filter (e: e.enable && e.cloudflare.enable) (
    lib.mapAttrsToList (name: e: e // { inherit name; }) top.services
  );

  # An empty subdomain is the base domain itself.
  hostnameOf =
    e:
    let
      c = e.cloudflare;
    in
    if c.hostname != null then
      c.hostname
    else if cfg.baseDomain == null then
      null
    else if c.subdomain == "" then
      cfg.baseDomain
    else
      "${c.subdomain}.${cfg.baseDomain}";

  unnamed = lib.filter (e: hostnameOf e == null) entries;
  named = lib.filter (e: hostnameOf e != null) entries;
  clashes = lib.filterAttrs (_: es: lib.length es > 1) (lib.groupBy hostnameOf named);
  public = map hostnameOf (lib.filter (e: !e.cloudflare.access) named);

  ready = cfg.tunnelId != null && cfg.credentialsFile != null;
in
{
  options.services.expose = {
    cloudflare = {
      enable = lib.mkEnableOption "publishing services.expose entries through a Cloudflare Tunnel";

      tunnelId = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "00000000-0000-0000-0000-000000000000";
        description = ''
          UUID of the tunnel (`cloudflared tunnel create` prints it). Names
          the `services.cloudflared.tunnels` entry this backend fills, so its
          other settings can be set there.
        '';
      };

      credentialsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/credentials/cloudflared-tunnel.json";
        description = ''
          The tunnel's credentials JSON, read at run time. Keep it out of the
          Nix store.
        '';
      };

      baseDomain = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "apps.example.com";
        description = ''
          Domain an entry's `cloudflare.subdomain` is put under. May stay
          null when every entry sets `cloudflare.hostname`.
        '';
      };

      default = mkOption {
        type = types.str;
        default = "http_status:404";
        description = "Service for requests that match no ingress rule.";
      };
    };

    services = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options.cloudflare = {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Publish this entry through the tunnel, once
                  `services.expose.cloudflare.enable` is set. Off by default:
                  this is the public edge.
                '';
              };

              subdomain = mkOption {
                type = types.str;
                default = name;
                defaultText = lib.literalExpression "<name>";
                description = ''
                  Label under `services.expose.cloudflare.baseDomain`; the empty
                  string publishes at the base domain itself.
                '';
              };

              hostname = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "status.example.org";
                description = "Full hostname, instead of `subdomain` under the base domain.";
              };

              access = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Whether a Cloudflare Access application is expected in front
                  of the hostname. Only records intent (Access is configured on
                  the Cloudflare side); false makes the build warn that the
                  hostname is public.
                '';
              };
            };

            config.urls =
              let
                host = hostnameOf config;
              in
              lib.mkIf (cfg.enable && config.enable && config.cloudflare.enable && host != null) {
                cloudflare = "https://${host}${config.path}";
              };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.tunnelId != null;
            message = "services.expose.cloudflare.enable requires tunnelId.";
          }
          {
            assertion = cfg.credentialsFile != null;
            message = "services.expose.cloudflare.enable requires credentialsFile.";
          }
          {
            assertion = unnamed == [ ];
            message = ''
              services.expose.services: ${lib.concatMapStringsSep ", " (e: e.name) unnamed}
              need cloudflare.hostname, or services.expose.cloudflare.baseDomain.
            '';
          }
          {
            assertion = clashes == { };
            message = ''
              services.expose.services: several entries use the same tunnel
              hostname: ${lib.concatStringsSep ", " (lib.attrNames clashes)}.
            '';
          }
        ];

        warnings = lib.optional (public != [ ]) ''
          services.expose.cloudflare publishes ${lib.concatStringsSep ", " public}
          with cloudflare.access = false, open to the whole internet.
        '';
      }

      # Without these, services.cloudflared would fail on its own types first;
      # the assertions above give the clearer message.
      (lib.mkIf ready {
        services.cloudflared = {
          enable = true;
          tunnels.${cfg.tunnelId} = {
            inherit (cfg) credentialsFile default;
            ingress = lib.listToAttrs (map (e: lib.nameValuePair (hostnameOf e) e.upstream) named);
          };
        };
      })
    ]
  );
}
