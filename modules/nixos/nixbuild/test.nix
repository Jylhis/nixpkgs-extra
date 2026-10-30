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

  off = evalNixos [ module ];

  on = evalNixos [
    module
    {
      services.nixbuild = {
        enable = true;
        privateKeyFile = "/root/.ssh/nixbuild";
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        maxJobs = 50;
      };
    }
  ];
in
runCases "nixos-nixbuild" {
  off-by-default = expect (!off.nix.distributedBuilds) "nixbuild enabled by default";

  enabled = allOf [
    (noFailedAssertions on)
    (expect on.nix.distributedBuilds "distributedBuilds not enabled")
    (expect on.nix.settings.builders-use-substitutes "builders-use-substitutes not enabled")
  ];

  key-config = allOf [
    (expect (lib.hasInfix "/root/.ssh/nixbuild" on.programs.ssh.extraConfig) "privateKeyFile not in ssh extraConfig")
    (expect (lib.hasInfix "eu.nixbuild.net" on.programs.ssh.extraConfig) "nixbuild.net host not in ssh extraConfig")
  ];

  known-hosts = expect (on.programs.ssh.knownHosts ? nixbuild) "nixbuild knownHost not configured";

  build-machines = allOf [
    (expect (builtins.length on.nix.buildMachines == 2) "expected 2 build machines for 2 systems")
    (expect (lib.all (
      m: m.hostName == "eu.nixbuild.net"
    ) on.nix.buildMachines) "not all build machines use eu.nixbuild.net")
    (expect (lib.all (
      m: m.maxJobs == 50
    ) on.nix.buildMachines) "not all build machines have maxJobs == 50")
  ];
}
