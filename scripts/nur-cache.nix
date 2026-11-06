# What nur-cache.yml builds and pushes to jylhis-extra for NUR users: every
# package from nur.nix that is available on this system, not broken and free,
# with all its outputs (the filter nur-packages-template's ci.nix uses), as
# <name>-<output>. An attrset, not a list: nix-eval-jobs (nix-fast-build)
# only walks attrsets.
# NUR users build against their own nixpkgs, so the job passes nixos-unstable:
#   nix-fast-build --file scripts/nur-cache.nix --skip-cached \
#     --arg pkgs 'import <nixpkgs> { }' -I nixpkgs=channel:nixos-unstable
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
lib.concatMapAttrs (
  name: drv: lib.genAttrs' drv.outputs (output: lib.nameValuePair "${name}-${output}" drv.${output})
) (lib.filterAttrs (_: cacheable) (import ../nur.nix { inherit pkgs; }))
