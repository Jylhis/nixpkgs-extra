# The reverse of no-nixpkgs-clash: every overrides/<attr>.nix must replace an
# attribute nixpkgs still has, so an upstream rename fails here instead of
# silently adding a new top-level package.
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  missing = lib.filter (name: !(pkgs ? ${name})) (import ../overrides { inherit lib; }).names;
in
if missing != [ ] then
  throw "overrides/ names attributes nixpkgs no longer has: ${lib.concatStringsSep ", " missing}"
else
  pkgs.runCommand "overrides-target-exists" { } "touch $out"
