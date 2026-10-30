#!/usr/bin/env bash
# `haxelib run lime` against the bundled haxelib repository; a caller
# HAXELIB_PATH is appended. Merged here because nixpkgs' haxe wrapper drops the
# exit status when HAXELIB_PATH holds more than one directory.
set -u

bundled=@repo@

if [ -z "${HAXELIB_PATH:-}" ]; then
  export HAXELIB_PATH="$bundled"
else
  merged=$(@mktemp@ -d)
  trap '@rm@ -rf "$merged"' EXIT
  IFS=: read -ra dirs <<<"$bundled:$HAXELIB_PATH"
  for dir in "${dirs[@]}"; do
    for entry in "$dir"/*; do
      [ -e "$entry" ] || continue
      name=${entry##*/}
      [ -e "$merged/$name" ] || @ln@ -s "$entry" "$merged/$name"
    done
  done
  export HAXELIB_PATH="$merged"
fi

# lime shells out to haxelib, haxe and neko by name; fall back to the build's.
export PATH="${PATH:+$PATH:}@haxebin@:@nekobin@"

@haxelib@ run lime "$@"
