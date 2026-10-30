# The ast-grep rules in rules/ (wired by sgconfig.yml) over every Nix file.
{ pkgs, ... }:
pkgs.runCommand "ast-grep" { nativeBuildInputs = [ pkgs.ast-grep ]; } ''
  cd ${../.}
  ast-grep scan --error
  touch $out
''
