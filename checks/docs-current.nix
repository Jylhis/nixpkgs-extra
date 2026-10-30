# The generated docs (scripts/docs.nix) must match the committed copies.
{ pkgs, repo, ... }:
let
  docs = import ../scripts/docs.nix { inherit pkgs repo; };
in
pkgs.runCommand "docs-current" { nativeBuildInputs = [ pkgs.diffutils ]; } ''
  stale=0
  diff -u ${../docs/nixos-options.md} ${docs.nixosOptions} || stale=1
  diff -u ${../docs/home-options.md} ${docs.homeOptions} || stale=1
  sed -n '/<!-- BEGIN PACKAGES -->/,/<!-- END PACKAGES -->/p' ${../README.md} | sed '1d;$d' > readme-list.md
  diff -u readme-list.md ${docs.packageList} || stale=1
  sed -n '/<!-- BEGIN OVERRIDES -->/,/<!-- END OVERRIDES -->/p' ${../README.md} | sed '1d;$d' > readme-overrides.md
  diff -u readme-overrides.md ${docs.overrideList} || stale=1
  if [ "$stale" = 1 ]; then
    echo "generated docs are stale; run: nix run .#update-docs"
    exit 1
  fi
  touch $out
''
