# `nix fmt`: nixfmt plus the nixf-diagnose and keep-sorted passes nixpkgs CI
# runs (ci/treefmt.nix), so a file formatted here passes there unchanged.
# flake.nix and checks/format.nix share it.
{ pkgs }:
let
  inherit (pkgs) lib;
in
pkgs.nixfmt-tree.override {
  settings.formatter = {
    keep-sorted = {
      command = lib.getExe pkgs.keep-sorted;
      includes = [ "*" ];
    };

    # Options copied from nixpkgs ci/treefmt.nix, ignore list included.
    nixf-diagnose = {
      command = lib.getExe pkgs.nixf-diagnose;
      includes = [ "*.nix" ];
      options = [
        "--auto-fix"
        "--ignore=sema-unused-def-lambda-noarg-formal"
        "--ignore=sema-unused-def-lambda-witharg-arg"
        "--ignore=sema-unused-def-lambda-witharg-formal"
        "--ignore=sema-unused-def-let"
        "--ignore=sema-primop-removed-prefix"
        "--ignore=sema-primop-overridden"
        "--ignore=sema-constant-overridden"
        "--ignore=sema-primop-unknown"
      ];
      # Run before nixfmt, so nixfmt cleans up after the fixes.
      priority = -1;
    };
  };
}
