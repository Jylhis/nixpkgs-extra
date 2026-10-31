# Evaluate every package the way nixpkgs' eval CI does (ci/eval/outpaths.nix):
# checkMeta rejects unknown meta keys and wrongly typed meta values, and
# allowAliases = false fails any use of a deprecated nixpkgs alias.
{ pkgs, repoWith, ... }:
let
  inherit (pkgs) lib;

  strictPkgs = import pkgs.path {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = {
      checkMeta = true;
      allowAliases = false;
      allowUnfree = true;
    };
  };

  available = lib.filterAttrs (
    _: pkg: lib.meta.availableOn strictPkgs.stdenv.hostPlatform pkg && !(pkg.meta.broken or false)
  ) (repoWith strictPkgs).packages;

  drvPaths = lib.mapAttrsToList (_: pkg: pkg.drvPath) available;
in
builtins.deepSeq drvPaths (pkgs.runCommand "check-meta" { } "touch $out")
