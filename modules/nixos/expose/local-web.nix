# localWeb backend: serves each HTTP entry as http://<name>.localhost through
# this repository's local-web module (loopback Caddy), so the same registry
# that feeds the tailnet and the tunnel also fills the local index page.
# local-web is a separate module; this only reads and writes its options when
# it is imported.
{
  config,
  lib,
  options,
  ...
}:
let
  inherit (lib) mkOption types;
  top = config.services.expose;
  cfg = top.localWeb;
  hasLocalWeb = options.services ? localWeb;

  isHttp = upstream: lib.hasPrefix "http://" upstream || lib.hasPrefix "https://" upstream;

  entries = lib.filterAttrs (_: e: e.enable && e.localWeb.enable) top.services;
in
{
  options.services.expose = {
    localWeb.enable = lib.mkEnableOption ''
      serving services.expose entries as `<name>.localhost` sites. Needs the
      local-web module, and enables services.localWeb'';

    services = mkOption {
      type = types.attrsOf (
        types.submodule (
          { name, config, ... }:
          {
            options.localWeb.enable = mkOption {
              type = types.bool;
              default = isHttp config.upstream;
              defaultText = lib.literalMD "whether `upstream` is an `http://` or `https://` URL";
              description = ''
                Serve this entry as `http://<name>.localhost`, once
                `services.expose.localWeb.enable` is set.
              '';
            };

            config.urls = lib.mkIf (cfg.enable && config.enable && config.localWeb.enable) {
              localWeb = "http://${name}.localhost${config.path}";
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
            assertion = hasLocalWeb;
            message = "services.expose.localWeb.enable needs the local-web module imported.";
          }
        ]
        ++ lib.mapAttrsToList (name: e: {
          assertion = isHttp e.upstream;
          message = "services.expose.services.${name}: localWeb needs an http:// or https:// upstream.";
        }) entries;
      }
      (lib.optionalAttrs hasLocalWeb {
        services.localWeb = {
          enable = true;
          sites = lib.mapAttrs (_: e: {
            inherit (e) title description order;
            extraConfig = "reverse_proxy ${e.upstream}";
          }) entries;
        };
      })
    ]
  );
}
