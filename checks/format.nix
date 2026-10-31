# `nix fmt` must leave the tree unchanged.
{ pkgs, ... }:
let
  formatter = import ../scripts/formatter.nix { inherit pkgs; };
in
pkgs.runCommand "format" { nativeBuildInputs = [ formatter ]; } ''
  cp -r ${../.} source
  chmod -R +w source
  cd source
  HOME=$TMPDIR treefmt --no-cache --fail-on-change
  touch $out
''
