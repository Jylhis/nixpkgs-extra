{
  lib,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  on = evalNixos [
    module
    {
      networking.hostName = "testhost";
      services.localWeb = {
        enable = true;
        sites.docs = {
          title = "Docs";
          port = 8080;
          order = 5;
        };
        sites.hidden = {
          enable = false;
          title = "Hidden";
          port = 9090;
        };
      };
    }
  ];
  off = evalNixos [ module ];

  vhosts = on.services.caddy.virtualHosts;
in
runCases "nixos-local-web" {
  off-by-default = expect (!off.services.caddy.enable) "caddy enabled without localWeb";
  enabled = allOf [
    (noFailedAssertions on)
    (expect on.services.caddy.enable "caddy not enabled")
  ];
  no-phoenix-needed = expect (!(on.services ? phoenix)) "services.phoenix unexpectedly defined";
  site-rendered = allOf [
    (expect (vhosts ? "http://docs.localhost") "enabled site has no vhost")
    (expect (lib.hasInfix "reverse_proxy 127.0.0.1:8080"
      vhosts."http://docs.localhost".extraConfig
    ) "proxy not rendered")
    (expect (!(vhosts ? "http://hidden.localhost")) "disabled site has a vhost")
  ];
  index-vhost = expect (vhosts ? "http://localhost") "index vhost missing";
}
