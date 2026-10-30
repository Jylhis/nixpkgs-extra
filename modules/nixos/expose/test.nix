{
  lib,
  module,
  nixosModules,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    allOf
    failedAssertions
    noFailedAssertions
    runCases
    ;

  eval = extra: evalNixos ([ module ] ++ extra);
  failsWith =
    config: infix:
    expect (lib.any (lib.hasInfix infix) (failedAssertions config)) "no assertion mentioning ${infix}";

  base = {
    networking.hostName = "box";
    services.expose.services = {
      media = {
        title = "Media";
        description = "Films & shows";
        upstream = "http://127.0.0.1:8096";
        tailscale.service = "media";
        cloudflare.enable = true;
      };
      admin = {
        upstream = "http://127.0.0.1:9000";
        path = "/ui/";
        tailscale.port = 8443;
      };
      ssh = {
        upstream = "tcp://127.0.0.1:22";
        tailscale = {
          protocol = "tcp";
          port = 2222;
        };
      };
      off = {
        enable = false;
        upstream = "http://127.0.0.1:1";
      };
    };
  };

  tunnelId = "00000000-0000-0000-0000-000000000000";
  cloudflareOn = {
    services.expose.cloudflare = {
      enable = true;
      inherit tunnelId;
      credentialsFile = "/run/credentials/tunnel.json";
      baseDomain = "apps.example.com";
    };
  };
  tailscaleOn = {
    services.tailscale.enable = true;
    services.expose.tailscale = {
      enable = true;
      domain = "tail.example";
    };
  };

  off = eval [ ];
  registryOnly = eval [ base ];

  tailscale = eval [
    base
    tailscaleOn
  ];
  script = (lib.head tailscale.systemd.services.tailscale-serve-expose.restartTriggers).text;
  urls = name: tailscale.services.expose.services.${name}.urls;

  tailscaleCase =
    entry:
    eval [
      tailscaleOn
      {
        services.expose.services.x = {
          upstream = "http://127.0.0.1:1";
        }
        // entry;
      }
    ];

  cloudflare = eval [
    base
    cloudflareOn
    { services.expose.services.ssh.cloudflare.access = false; }
    { services.expose.services.ssh.cloudflare.enable = true; }
  ];
  ingress = cloudflare.services.cloudflared.tunnels.${tunnelId}.ingress;

  landing = eval [
    base
    tailscaleOn
    cloudflareOn
    {
      services.expose.landing.enable = true;
      services.expose.services.landing.cloudflare.enable = true;
    }
  ];
  html = (lib.head landing.systemd.services.expose-landing.restartTriggers).text;

  localWeb = eval [
    nixosModules.local-web
    base
    { services.expose.localWeb.enable = true; }
  ];
in
runCases "nixos-expose" {
  off-by-default = allOf [
    (noFailedAssertions off)
    (expect (!(off.systemd.services ? tailscale-serve-expose)) "tailscale unit without enable")
    (expect (!(off.systemd.services ? expose-landing)) "landing unit without enable")
    (expect (!off.services.cloudflared.enable) "cloudflared enabled without enable")
  ];
  registry-is-inert = allOf [
    (noFailedAssertions registryOnly)
    (expect (
      !(registryOnly.systemd.services ? tailscale-serve-expose)
    ) "entries alone started a backend")
    (expect (registryOnly.services.expose.services.media.urls == { }) "urls filled with no backend")
  ];

  tailscale-renders = allOf [
    (noFailedAssertions tailscale)
    (expect (lib.hasInfix "tailscale serve --bg --https=8443 http://127.0.0.1:9000" script) "node-port serve missing")
    (expect (lib.hasInfix "tailscale serve --bg --service=svc:media --https=443 http://127.0.0.1:8096" script) "service serve missing")
    (expect (lib.hasInfix "tailscale serve --bg --tcp=2222 tcp://127.0.0.1:22" script) "tcp serve missing")
    (expect (lib.hasInfix "tailscale serve reset" script) "no reset before apply")
    (expect (!lib.hasInfix "127.0.0.1:1 " script) "disabled entry served")
  ];
  tailscale-urls = allOf [
    (expect ((urls "media").tailscale == "https://media.tail.example/") "service url")
    (expect ((urls "admin").tailscale == "https://box.tail.example:8443/ui/") "node-port url")
    (expect ((urls "ssh").tailscale == "tcp://box.tail.example:2222") "tcp url")
  ];
  tailscale-needs-daemon = failsWith (eval [
    base
    { services.expose.tailscale.enable = true; }
  ]) "requires services.tailscale.enable";
  tailscale-not-with-nixpkgs-serve = failsWith (eval [
    tailscaleOn
    {
      services.tailscale.serve = {
        enable = true;
        services.a.endpoints."tcp:443" = "http://127.0.0.1:1";
      };
    }
  ]) "Enable only one";
  tailscale-listener-clash = failsWith (eval [
    tailscaleOn
    {
      services.expose.services = {
        a.upstream = "http://127.0.0.1:1";
        b.upstream = "http://127.0.0.1:2";
      };
    }
  ]) "use the same tailscale";
  funnel-port = failsWith (tailscaleCase {
    tailscale = {
      funnel = true;
      port = 8080;
    };
  }) "funnel listens only on ports";
  funnel-http = failsWith (tailscaleCase {
    tailscale = {
      funnel = true;
      protocol = "http";
    };
  }) "not http";
  funnel-renders = expect (lib.hasInfix "tailscale funnel --bg --https=443"
    (lib.head
      (tailscaleCase { tailscale.funnel = true; }).systemd.services.tailscale-serve-expose.restartTriggers
    ).text
  ) "funnel not rendered";
  funnel-service = failsWith (tailscaleCase {
    tailscale = {
      funnel = true;
      service = "x";
    };
  }) "funnel cannot be combined with";
  tailscale-stop-clears =
    let
      unit = tailscale.systemd.services.tailscale-serve-expose.serviceConfig;
      stop = (lib.elemAt tailscale.systemd.services.tailscale-serve-expose.restartTriggers 1).text;
    in
    allOf [
      (expect unit.RemainAfterExit "stop would not run on removal")
      (expect (lib.hasInfix "tailscale funnel reset" stop) "stop leaves funnel state")
      (expect (lib.hasInfix "tailscale serve reset" stop) "stop leaves serve state")
      (expect (lib.hasInfix "tailscale serve clear svc:media" stop) "stop leaves service state")
    ];
  service-name-checked = failsWith (tailscaleCase {
    tailscale.service = "svc:Media";
  }) "tailscale.service must be a DNS";

  cloudflare-ingress = allOf [
    (noFailedAssertions cloudflare)
    (expect cloudflare.services.cloudflared.enable "cloudflared not enabled")
    (expect (ingress."media.apps.example.com" == "http://127.0.0.1:8096") "media ingress")
    (expect (!(ingress ? "admin.apps.example.com")) "entry without cloudflare.enable published")
    (expect (
      cloudflare.services.cloudflared.tunnels.${tunnelId}.default == "http_status:404"
    ) "default is not a closed 404")
    (expect (
      cloudflare.services.expose.services.media.urls.cloudflare == "https://media.apps.example.com/"
    ) "cloudflare url")
  ];
  cloudflare-warns-public = expect (lib.any (lib.hasInfix "ssh.apps.example.com") cloudflare.warnings) "no warning for access = false";
  cloudflare-hostname-override = expect (
    (eval [
      base
      cloudflareOn
      { services.expose.services.media.cloudflare.hostname = "media.example.org"; }
    ]).services.cloudflared.tunnels.${tunnelId}.ingress
      ? "media.example.org"
  ) "hostname override ignored";
  cloudflare-missing-settings =
    let
      config = eval [
        base
        { services.expose.cloudflare.enable = true; }
      ];
    in
    allOf [
      (failsWith config "requires tunnelId")
      (failsWith config "requires credentialsFile")
      (failsWith config "need cloudflare.hostname")
      (expect (!config.services.cloudflared.enable) "cloudflared configured without credentials")
    ];
  cloudflare-hostname-clash = failsWith (eval [
    base
    cloudflareOn
    {
      services.expose.services.admin.cloudflare = {
        enable = true;
        subdomain = "media";
      };
    }
  ]) "use the same tunnel";

  landing-renders = allOf [
    (noFailedAssertions landing)
    (expect (
      (lib.head landing.systemd.services.expose-landing.restartTriggers).name == "index.html"
    ) "docroot is not a directory (darkhttpd 500s on a file)")
    (expect (lib.hasInfix "<h1>box</h1>" html) "heading")
    (expect (lib.hasInfix "Films &amp; shows" html) "description not escaped")
    (expect (lib.hasInfix ''href="https://media.tail.example/"'' html) "tailnet link")
    (expect (lib.hasInfix ''href="https://media.apps.example.com/"'' html) "tunnel link")
    (expect (!lib.hasInfix "Landing page" html) "page lists itself")
    (expect (!lib.hasInfix "127.0.0.1:1" html) "disabled entry listed")
  ];
  landing-registers = allOf [
    (expect (lib.hasInfix "tailscale serve --bg --https=443 http://127.0.0.1:8780" (lib.head landing.systemd.services.tailscale-serve-expose.restartTriggers).text) "landing not served on the node")
    (expect (
      landing.services.cloudflared.tunnels.${tunnelId}.ingress."apps.example.com"
      == "http://127.0.0.1:8780"
    ) "landing not at the base domain")
  ];

  local-web-needs-module = failsWith (eval [
    base
    { services.expose.localWeb.enable = true; }
  ]) "needs the local-web module";
  local-web-sites = allOf [
    (noFailedAssertions localWeb)
    (expect localWeb.services.localWeb.enable "localWeb not enabled")
    (expect (
      localWeb.services.localWeb.sites.media.extraConfig == "reverse_proxy http://127.0.0.1:8096"
    ) "media site")
    (expect (localWeb.services.localWeb.sites.media.title == "Media") "title not passed on")
    (expect (!(localWeb.services.localWeb.sites ? ssh)) "tcp entry became a site")
    (expect (
      localWeb.services.expose.services.admin.urls.localWeb == "http://admin.localhost/ui/"
    ) "localhost url")
  ];
}
