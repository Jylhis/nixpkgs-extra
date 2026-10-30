{
  lib,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalHome
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  on = evalHome [
    module
    { programs.openviking-server.enable = true; }
  ];
  off = evalHome [ module ];
  keyed = evalHome [
    module
    {
      programs.openviking-server = {
        enable = true;
        apiKeyFile = "/run/user/1000/key";
        afterUnits = [ "key-provisioner.service" ];
      };
    }
  ];
  badFallback = evalHome [
    module
    {
      programs.openviking-server = {
        enable = true;
        embedding.fallback.model = "m";
      };
    }
  ];
in
runCases "home-openviking-server" {
  off-by-default = expect (
    !(off.systemd.user.services ? openviking-server)
  ) "unit defined without enable";
  enables-unit = allOf [
    (expect (on.systemd.user.services ? openviking-server) "unit missing")
    (noFailedAssertions on)
  ];
  package-default = expect (
    on.programs.openviking-server.package.pname == "openviking-server"
  ) "package default does not resolve to openviking-server";
  after-units = expect (lib.elem "key-provisioner.service" keyed.systemd.user.services.openviking-server.Unit.After) "afterUnits not ordered before the unit";
  # Home Manager aborts evaluation on a failed assertion.
  fallback-needs-key = expect (
    !(builtins.tryEval badFallback.programs.openviking-server.enable).success
  ) "fallback without a key did not assert";
}
