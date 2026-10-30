# Landing page: one static HTML page, built at evaluation time, listing every
# enabled services.expose entry with the URLs its backends publish. darkhttpd
# serves it on loopback, and it registers itself as the `landing` entry so the
# same backends front it (on the node's own name, or at the tunnel's base
# domain).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkOption types;
  top = config.services.expose;
  cfg = top.landing;
  esc = lib.escapeXML;

  listed = lib.sort (a: b: if a.order == b.order then a.name < b.name else a.order < b.order) (
    lib.filter (e: e.enable && e.name != "landing") (
      lib.mapAttrsToList (name: e: e // { inherit name; }) top.services
    )
  );

  links =
    e:
    lib.concatMapStrings (url: " <a class=\"url\" href=\"${esc url}\">${esc url}</a>") (
      lib.attrValues e.urls
    );

  item =
    e:
    "<li><span class=\"title\">${esc e.title}</span>"
    + lib.optionalString (e.description != "") " <span class=\"desc\">${esc e.description}</span>"
    + "${links e}</li>\n";

  # darkhttpd answers 500 for a file docroot, so the page is index.html in a
  # directory.
  page = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${esc cfg.title}</title>
    <style>
      body { font: 16px/1.5 system-ui, sans-serif; max-width: 40rem; margin: 3rem auto; padding: 0 1rem; }
      @media (prefers-color-scheme: dark) { body { background: #111; color: #ddd; } a { color: #8ab4f8; } }
      ul { padding: 0; list-style: none; }
      li { margin: .75rem 0; }
      .title { font-weight: 600; }
      .desc { opacity: .7; }
      .url { display: block; font-size: .85rem; overflow-wrap: anywhere; }
    </style>
    </head>
    <body>
    <h1>${esc cfg.title}</h1>
    <ul>
    ${lib.concatMapStrings item listed}</ul>
    </body>
    </html>
  '';
in
{
  options.services.expose.landing = {
    enable = lib.mkEnableOption "a landing page listing the services.expose entries";

    port = mkOption {
      type = types.port;
      default = 8780;
      description = "Loopback port the page is served on.";
    };

    title = mkOption {
      type = types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Page heading.";
    };

    register = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Add the page itself as `services.expose.services.landing`, so the
        enabled backends publish it: on port 443 of this node for Tailscale,
        and at the tunnel's base domain if `cloudflare.enable` is set on the
        entry. Its options can be changed there like any other entry's.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.expose.services = lib.mkIf cfg.register {
      landing = {
        title = lib.mkDefault "Landing page";
        upstream = "http://127.0.0.1:${toString cfg.port}";
        cloudflare.subdomain = lib.mkDefault "";
        # local-web has its own index on http://localhost.
        localWeb.enable = lib.mkDefault false;
      };
    };

    systemd.services.expose-landing = {
      description = "Landing page for services.expose";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ page ];
      serviceConfig = {
        ExecStart = "${lib.getExe pkgs.darkhttpd} ${page} --addr 127.0.0.1 --port ${toString cfg.port}";
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        RestrictNamespaces = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
        MemoryDenyWriteExecute = true;
        IPAddressDeny = "any";
        IPAddressAllow = "localhost";
      };
    };
  };
}
