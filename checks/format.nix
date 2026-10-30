# `nix fmt` must leave the tree unchanged.
{ pkgs, ... }:
pkgs.runCommand "format" { nativeBuildInputs = [ pkgs.nixfmt-tree ]; } ''
  cp -r ${../.} source
  chmod -R +w source
  cd source
  HOME=$TMPDIR treefmt --no-cache --fail-on-change
  touch $out
''
