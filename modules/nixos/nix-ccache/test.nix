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
      programs.nix-ccache.enable = true;
    }
  ];
  off = evalNixos [ module ];
  custom = evalNixos [
    module
    {
      programs.nix-ccache.enable = true;
      programs.ccache.cacheDir = "/srv/ccache";
    }
  ];
in
runCases "nixos-nix-ccache" {
  off-by-default = expect (
    !off.programs.nix-ccache.enable
  ) "nix-ccache enabled without explicit enable";
  enabled = allOf [
    (noFailedAssertions on)
    (expect on.programs.nix-ccache.enable "nix-ccache not enabled")
  ];
  ccache-enabled = expect on.programs.ccache.enable "ccache not enabled when nix-ccache is enabled";
  wrapper-set = expect (on.security.wrappers ? nix-ccache) "nix-ccache wrapper not configured";
  default-cache-dir = expect (lib.hasInfix "-DCACHE_DIR='\"/var/cache/ccache\"'" on.programs.nix-ccache.package.buildPhase) "default package lost /var/cache/ccache";
  custom-cache-dir = expect (lib.hasInfix "-DCACHE_DIR='\"/srv/ccache\"'" custom.programs.nix-ccache.package.buildPhase) "programs.ccache.cacheDir does not reach the shim package";
}
