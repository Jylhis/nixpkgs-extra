# VM test for the lazylibrarian module.
#
# The eval test checks the rendered unit; only a running service shows that
# the CLI flags are the ones LazyLibrarian accepts, that it can write its
# data directory under the hardening, and that the web UI answers on `port`.
{ pkgs, module, ... }:
pkgs.testers.runNixOSTest {
  name = "lazylibrarian-vm";

  nodes.machine = {
    imports = [ module ];
    services.lazylibrarian = {
      enable = true;
      port = 8099;
    };
  };

  testScript = ''
    machine.wait_for_unit("lazylibrarian.service")
    machine.wait_for_open_port(8099)
    machine.succeed("curl --fail --silent --location http://127.0.0.1:8099/ | grep -q LazyLibrarian")
    machine.succeed("test -f /var/lib/lazylibrarian/lazylibrarian.db")
    machine.succeed("test -f /var/lib/lazylibrarian/config.ini")
    machine.systemctl("stop lazylibrarian.service")
    machine.succeed("journalctl -u lazylibrarian.service | grep -q 'is exiting'")
    machine.fail("journalctl -u lazylibrarian.service | grep -q Traceback")
  '';
}
