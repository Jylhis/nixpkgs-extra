# Loopback Caddy giving each local web UI a *.localhost name on port 80.
# *.localhost resolves to loopback through nss-myhostname or systemd-resolved
# and in browsers, so no /etc/hosts entries are needed. Only enabled sites
# get a vhost, and http://localhost lists them. CUPS registers itself, and so
# does Phoenix when another module defining services.phoenix is imported; add
# the rest through services.localWeb.sites.
{
  config,
  lib,
  options,
  pkgs,
  ...
}:
let
  cfg = config.services.localWeb;
  inherit (config.services) printing;
  # Optional integration: services.phoenix comes from a module this repo does
  # not ship, so it is only read and written when that module is imported.
  hasPhoenix = options.services ? phoenix;

  site = lib.types.submodule {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to serve and list this site.";
      };
      title = lib.mkOption {
        type = lib.types.str;
        description = "Link text on the index page.";
      };
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Line shown next to the link.";
      };
      port = lib.mkOption {
        type = lib.types.nullOr lib.types.port;
        default = null;
        description = "Loopback port to proxy to; null leaves the block to extraConfig.";
      };
      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Caddy directives before the proxy, or the whole block without a port.";
      };
      order = lib.mkOption {
        type = lib.types.int;
        default = 100;
        description = "Position on the index page (then by name).";
      };
    };
  };

  sites = lib.sort (a: b: if a.order == b.order then a.name < b.name else a.order < b.order) (
    lib.mapAttrsToList (name: s: s // { inherit name; }) (lib.filterAttrs (_: s: s.enable) cfg.sites)
  );

  siteConfig =
    s:
    if s.port == null then
      s.extraConfig
    else
      ''
        ${s.extraConfig}
        reverse_proxy 127.0.0.1:${toString s.port}
      '';

  url = s: "http://${s.name}.localhost";

  host = lib.escapeXML config.networking.hostName;

  index = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <title>${host}</title>
    <style>
      body { font: 16px/1.5 system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; }
      @media (prefers-color-scheme: dark) { body { background: #111; color: #ddd; } a { color: #8ab4f8; } }
      li { margin: .5rem 0; }
      span { opacity: .7; }
    </style>
    </head>
    <body>
    <h1>${host}</h1>
    <ul>
    ${
      lib.concatMapStrings (
        s:
        "<li><a href=\"${url s}\">${lib.escapeXML s.title}</a> <span>${lib.escapeXML s.description}</span></li>\n"
      ) sites
    }</ul>
    </body>
    </html>
  '';
in
{
  options.services.localWeb = {
    enable = lib.mkEnableOption "*.localhost names for local web UIs";

    sites = lib.mkOption {
      type = lib.types.attrsOf site;
      default = { };
      example = lib.literalExpression ''
        {
          llm = {
            title = "llama-swap";
            port = 8080;
            extraConfig = "redir / /ui/";
          };
        }
      '';
      description = "Sites served as http://<name>.localhost and listed on http://localhost.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.localWeb.sites = {
          cups = {
            title = "CUPS";
            description = "Printers and print jobs";
            inherit (printing) enable;
            # CUPS rejects Host headers it does not know.
            extraConfig = ''
              reverse_proxy 127.0.0.1:631 {
                header_up Host localhost
              }
            '';
            order = 90;
          };
        };

        services.caddy = {
          enable = true;
          globalConfig = ''
            auto_https off
            default_bind 127.0.0.1 [::1]
          '';
          virtualHosts = {
            "http://localhost".extraConfig = ''
              root * ${index}
              file_server
            '';
          }
          // lib.listToAttrs (map (s: lib.nameValuePair (url s) { extraConfig = siteConfig s; }) sites);
        };

      }
      (lib.optionalAttrs hasPhoenix {
        services.localWeb.sites.phoenix = {
          title = "Phoenix";
          description = "OpenInference traces and evals";
          inherit (config.services.phoenix) enable port;
          order = 11;
        };
        # Phoenix builds its redirects and cookie scope from this URL.
        services.phoenix.url = "http://phoenix.localhost";
      })
    ]
  );
}
