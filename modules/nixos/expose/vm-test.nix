# What the eval test can't show: that darkhttpd actually serves the generated
# page under the unit's hardening, and that a localWeb entry proxies through
# local-web's Caddy to its upstream. The Tailscale and Cloudflare backends
# need a tailnet and a tunnel, so they stay in the eval test.
{
  pkgs,
  module,
  nixosModules,
  ...
}:
pkgs.testers.runNixOSTest {
  name = "expose-vm";

  nodes.machine = {
    imports = [
      module
      nixosModules.local-web
    ];

    networking.hostName = "box";

    systemd.services.hello = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        DynamicUser = true;
        ExecStart = "${pkgs.lib.getExe pkgs.darkhttpd} ${pkgs.writeTextDir "index.html" "hello from upstream"} --addr 127.0.0.1 --port 9000";
      };
    };

    services.expose = {
      landing.enable = true;
      localWeb.enable = true;
      services.hello = {
        title = "Hello";
        description = "A test upstream";
        upstream = "http://127.0.0.1:9000";
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("expose-landing.service")
    machine.wait_for_open_port(8780)

    page = machine.succeed("curl -fsS http://127.0.0.1:8780/")
    assert "Hello" in page, page
    assert "A test upstream" in page, page
    assert 'href="http://hello.localhost/"' in page, page

    machine.wait_for_unit("hello.service")
    machine.wait_for_unit("caddy.service")
    machine.wait_for_open_port(80)

    # curl resolves *.localhost to loopback itself.
    body = machine.succeed("curl -fsS http://hello.localhost/")
    assert "hello from upstream" in body, body

    index = machine.succeed("curl -fsS http://localhost/")
    assert "http://hello.localhost" in index, index
  '';
}
