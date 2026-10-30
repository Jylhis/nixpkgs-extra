# The overlay puts every public package at the top level, so none may share a
# name with a nixpkgs attribute; rename ours instead (AGENTS.md, Naming).
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;
  clashes = lib.filter (name: pkgs ? ${name}) (lib.attrNames repo.packages);
in
if clashes != [ ] then
  throw "Package names already taken in nixpkgs, rename them: ${lib.concatStringsSep ", " clashes}"
else
  pkgs.runCommand "no-nixpkgs-clash" { } "touch $out"
