{
  lib,
  pkgs,
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

  stub = pkgs.writeShellScriptBin "agentsview" "true";

  off = evalHome [ module ];

  noPackage = evalHome [
    module
    { services.agentsview.enable = true; }
  ];

  on = evalHome [
    module
    {
      services.agentsview = {
        enable = true;
        package = stub;
        port = 9000;
        publicOrigins = [ "http://agentsview.example.org" ];
        dataDir = "/var/lib/alice/av";
      };
    }
  ];

  unit = on.systemd.user.services.agentsview.Service;
  execStart = lib.concatStringsSep " " (lib.toList unit.ExecStart);
in
runCases "home-agentsview" {
  off-by-default = allOf [
    (expect (!off.services.agentsview.enable) "enabled without enable = true")
    (noFailedAssertions off)
  ];
  # Home Manager throws its failed assertions on any read of the config.
  package-null-asserts = expect (
    !(builtins.tryEval noPackage.services.agentsview.enable).success
  ) "enabling without a package does not assert";
  stub-package = allOf [
    (noFailedAssertions on)
    (expect (builtins.elem stub on.home.packages) "package not installed")
    (expect (builtins.match ".* --port 9000 .*" execStart != null) "port not rendered")
    (expect (
      builtins.match ".*--public-origin.*agentsview.example.org.*" execStart != null
    ) "public origin not rendered")
    (expect (builtins.elem "AGENTSVIEW_DATA_DIR=/var/lib/alice/av" unit.Environment) "dataDir not rendered")
    (expect (builtins.elem "-/var/lib/alice/.claude" unit.ReadOnlyPaths) "session roots not read-only")
  ];
}
