# The overlay must apply to a real nixpkgs: every public package is reachable
# at the top level and evaluates to the same derivation as `packages`.
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;
  extended = pkgs.extend repo.overlays.default;
  mismatched = lib.filter (name: extended.${name}.drvPath != repo.packages.${name}.drvPath) (
    lib.attrNames (
      lib.filterAttrs (_: p: lib.meta.availableOn pkgs.stdenv.hostPlatform p) repo.packages
    )
  );
in
if mismatched != [ ] then
  throw "overlay builds differ from packages: ${lib.concatStringsSep ", " mismatched}"
else
  pkgs.runCommand "overlay" { } "touch $out"
