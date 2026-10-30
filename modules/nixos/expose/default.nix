# One registry of the local services a host offers, and opt-in backends that
# publish it. A service module only declares what it is
# (`services.expose.services.<name>`: an upstream URL, a title); each backend
# turns the enabled entries into its own config:
#
#   tailscale  `tailscale serve` / `tailscale funnel` on the tailnet
#   cloudflare ingress rules on a Cloudflare Tunnel (nixpkgs services.cloudflared)
#   localWeb   `<name>.localhost` sites through the local-web module
#   landing    a static page listing every entry and the URLs it has
#
# Every backend is off until its own `enable`. Backends add per-entry options
# to the entry type and record their published URLs in the entry's `urls`.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    ./tailscale.nix
    ./cloudflare.nix
    ./local-web.nix
    ./landing.nix
  ];

  options.services.expose.services = mkOption {
    default = { };
    description = ''
      Local services to publish. Each entry is inert until a backend
      (`services.expose.tailscale`, `.cloudflare`, `.localWeb`, `.landing`)
      is enabled.
    '';
    example = lib.literalExpression ''
      {
        jellyfin = {
          title = "Jellyfin";
          upstream = "http://127.0.0.1:8096";
          tailscale.service = "jellyfin";
        };
      }
    '';
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        {
          options = {
            enable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether backends publish this entry.";
            };

            title = mkOption {
              type = types.str;
              default = name;
              defaultText = lib.literalExpression "<name>";
              description = "Human-readable name, shown on the landing page.";
            };

            description = mkOption {
              type = types.str;
              default = "";
              description = "One line shown next to the title.";
            };

            upstream = mkOption {
              type = types.str;
              example = "http://127.0.0.1:8096";
              description = ''
                URL the backends forward to, usually a loopback address
                (`http://127.0.0.1:PORT`, or `tcp://127.0.0.1:PORT` for a raw
                TCP service).
              '';
            };

            path = mkOption {
              type = types.str;
              default = "/";
              example = "/ui/";
              description = ''
                Path appended to the published URLs in `urls`, for a UI that
                lives below the root. Routing is unchanged: the whole host
                still forwards to `upstream`.
              '';
            };

            order = mkOption {
              type = types.int;
              default = 100;
              description = "Position on the landing page (then by name).";
            };

            urls = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = ''
                URLs the enabled backends publish this entry at, keyed by
                backend (`tailscale`, `cloudflare`, `localWeb`). Filled in by
                the backends; read it, don't set it.
              '';
            };
          };
        }
      )
    );
  };
}
