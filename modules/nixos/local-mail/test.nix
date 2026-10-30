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
      services.localMail = {
        enable = true;
        rootAlias = "alice";
      };
    }
  ];
  off = evalNixos [ module ];
in
runCases "nixos-local-mail" {
  off-by-default = expect (!off.services.postfix.enable) "postfix enabled without localMail";
  enabled = allOf [
    (noFailedAssertions on)
    (expect on.services.postfix.enable "postfix not enabled")
  ];
  hostname-set = expect (
    on.services.postfix.settings.main.myhostname == "testhost.localhost"
  ) "myhostname not set correctly";
  root-alias = expect (on.services.postfix.rootAlias == "alice") "rootAlias not set";
  mailutils-included = expect (lib.any (
    p: p.pname == "mailutils"
  ) on.environment.systemPackages) "mailutils not in systemPackages";
  no-remote-delivery = allOf [
    (expect (
      on.services.postfix.settings.main.default_transport == "error:local delivery only"
    ) "default_transport still delivers to remote domains")
    (expect (
      on.services.postfix.settings.main.relay_transport == "error:local delivery only"
    ) "relay_transport still delivers to remote domains")
    (expect ((on.services.postfix.settings.main.relayhost or [ ]) == [ ]) "a relayhost is set")
  ];
  local-delivery-kept = expect (
    on.services.postfix.settings.main.mydestination == [
      "$myhostname"
      "localhost"
    ]
  ) "local destinations changed";
}
