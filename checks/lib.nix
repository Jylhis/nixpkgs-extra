# Helpers for modules/<kind>/<name>/test.nix: evaluate a minimal NixOS or
# Home Manager configuration and assert on the rendered config. Forces only
# what a case reads, so a test costs an evaluation, not a build or a VM.
{ pkgs, home-manager }:
let
  inherit (pkgs) lib;
in
rec {
  evalNixos =
    modules:
    (import (pkgs.path + "/nixos/lib/eval-config.nix") {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = modules ++ [
        {
          nixpkgs.pkgs = pkgs;
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "/dev/vda";
            fsType = "ext4";
          };
          system.stateVersion = "26.05";
        }
      ];
    }).config;

  evalHome =
    modules:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = modules ++ [
        {
          home = {
            username = "alice";
            homeDirectory = "/var/lib/alice";
            stateVersion = "26.05";
          };
        }
      ];
    }).config;

  failedAssertions = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);

  # A passing case is null; a failing one is its reason.
  expect = cond: reason: if cond then null else reason;
  allOf = lib.findFirst (r: r != null) null;
  noFailedAssertions =
    config:
    let
      failed = failedAssertions config;
    in
    expect (failed == [ ]) "unexpected failed assertions: ${lib.concatStringsSep "; " failed}";

  # cases: { <case name> = null | "<reason>"; } -> a check derivation that
  # fails evaluation listing every failing case.
  runCases =
    name: cases:
    let
      failures = lib.filterAttrs (_: r: r != null) cases;
    in
    if failures == { } then
      pkgs.runCommand name { } "touch $out"
    else
      throw (
        "${name}:\n" + lib.concatStringsSep "\n" (lib.mapAttrsToList (case: r: "  ${case}: ${r}") failures)
      );
}
