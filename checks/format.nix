# `nix fmt` must leave the tree unchanged.
{ pkgs, ... }:
let
  formatter = import ../scripts/formatter.nix { inherit pkgs; };
in
pkgs.runCommand "format" { nativeBuildInputs = [ formatter ]; } ''
  cp -r ${../.} source
  chmod -R +w source
  cd source
  # Without a git worktree treefmt walks from its config file's directory,
  # /nix/store; the store paths of concurrent builds then come and go mid-walk.
  HOME=$TMPDIR treefmt --no-cache --fail-on-change --tree-root .
  touch $out
''
