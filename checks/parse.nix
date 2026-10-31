# Every Nix file parses without warnings (e.g. deprecated syntax), as in
# nixpkgs ci/parse.nix.
{ pkgs, ... }:
let
  inherit (pkgs) lib;
  source = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.fileFilter (file: file.hasExt "nix") ../.;
  };
in
pkgs.runCommand "parse" { nativeBuildInputs = [ pkgs.nix ]; } ''
  export NIX_STORE_DIR=$TMPDIR/store
  export NIX_STATE_DIR=$TMPDIR/state
  nix-store --init

  set -o pipefail
  cd ${source}
  find . -type f -name '*.nix' -print0 \
    | xargs -0 -P "$NIX_BUILD_CORES" nix-instantiate --parse 2>&1 >/dev/null \
    | {
      if grep warning; then
        echo "nix-instantiate --parse printed warnings" >&2
        exit 1
      fi
    }
  touch $out
''
