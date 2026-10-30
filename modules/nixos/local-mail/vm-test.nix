# Mail to a local user is delivered; mail to an outside address bounces back
# to the sender locally instead of being sent over SMTP.
{ pkgs, module, ... }:
pkgs.testers.runNixOSTest {
  name = "local-mail-vm";

  nodes.machine = {
    imports = [ module ];
    networking.hostName = "machine";
    services.localMail.enable = true;
    users.users.alice = {
      isNormalUser = true;
    };
  };

  testScript = ''
    machine.wait_for_unit("postfix.service")

    # Local delivery keeps working.
    machine.succeed("echo hello | sendmail -f alice alice@machine.localhost")
    machine.wait_until_succeeds("grep -q hello /var/spool/mail/alice")

    # A remote recipient bounces to the sender's local mailbox, with no
    # attempt to reach another host.
    machine.succeed("echo nope | sendmail -f alice someone@example.com")
    machine.wait_until_succeeds("grep -q 'local delivery only' /var/spool/mail/alice")
    machine.wait_until_succeeds("test -z \"$(mailq | grep -v 'Mail queue is empty')\"")
  '';
}
