# NUR entry point (repos.json `"file": "nur.nix"`). NUR calls it with only
# `pkgs` and lists top-level derivations, so the packages are flattened next
# to the names NUR reserves for modules, overlays and lib. `scope` and
# `overrides` stay out: they hold helpers and nixpkgs' own attributes.
{ pkgs }:
let
  repo = import ./default.nix { inherit pkgs; };
  reserved = {
    inherit (repo)
      lib
      nixosModules
      homeModules
      overlays
      ;
  };
  clashes = builtins.attrNames (builtins.intersectAttrs reserved repo.packages);
in
assert pkgs.lib.assertMsg (
  clashes == [ ]
) "nur.nix: packages shadow NUR's reserved names: ${toString clashes}";
repo.packages // reserved
