# What nur-cache.yml builds and pushes to jylhis-extra for NUR users: every
# package from nur.nix that is available on this system, not broken and free,
# with all its outputs (the filter nur-packages-template's ci.nix uses).
# NUR users build against their own nixpkgs, so the job passes nixos-unstable:
#   nix-build scripts/nur-cache.nix --arg pkgs 'import <nixpkgs> { }' \
#     -I nixpkgs=channel:nixos-unstable
{ pkgs }:
let
  inherit (pkgs) lib;

  cacheable =
    drv:
    lib.isDerivation drv
    && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
    && !(drv.meta.broken or false)
    && lib.all (license: license.free or true) (lib.toList (drv.meta.license or [ ]));
in
lib.concatMap (drv: map (output: drv.${output}) drv.outputs) (
  lib.filter cacheable (lib.attrValues (import ../nur.nix { inherit pkgs; }))
)
