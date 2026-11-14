# `nix run .#update [-- <name>...]` from the repo root: bump every package
# that sets passthru.updateScript (or only those named), build what changed
# and regenerate the docs. `--list [<name>...]` prints the names as JSON, for
# the update workflow's matrix.
{ pkgs, packages }:
let
  inherit (pkgs) lib;

  # { <name> = [ <nix-update flag> ... ]; }, from the updateScript's command.
  updatable = lib.concatMapAttrs (
    name: p:
    let
      cmd = p.updateScript.command or p.updateScript or null;
    in
    lib.optionalAttrs (lib.isList cmd && cmd != [ ]) { ${name} = lib.tail cmd; }
  ) packages;

  list = pkgs.writeText "updatable.json" (builtins.toJSON updatable);
in
pkgs.writeShellApplication {
  name = "update";
  runtimeInputs = [
    pkgs.jq
    pkgs.nix-update
  ];
  text = ''
    list=${list}

    list_only=false
    if [ "''${1:-}" = --list ]; then
      list_only=true
      shift
    fi

    for name in "$@"; do
      if ! jq -e --arg n "$name" 'has($n)' "$list" > /dev/null; then
        echo "update: $name is not a package with an updateScript" >&2
        exit 2
      fi
    done

    if [ $# -eq 0 ]; then
      mapfile -t names < <(jq -r 'keys[]' "$list")
    else
      names=("$@")
    fi

    if $list_only; then
      jq -cn '$ARGS.positional' --args "''${names[@]}"
      exit
    fi

    # Called on the left of ||, where errexit is off: every step returns.
    update_one() {
      local name=$1 old new args
      old=$(nix eval --raw ".#$name.version") || return 1
      mapfile -t args < <(jq -r --arg n "$name" '.[$n][]' "$list")
      # Not --flake: with lazy trees nix-update evaluates the flake's store
      # path, which is never copied after it edits the file, so the hash step
      # fails and leaves only the version bumped.
      nix-update -f ./default.nix "''${args[@]}" "packages.$name" || return 1
      new=$(nix eval --raw ".#$name.version") || return 1
      if [ "$old" = "$new" ]; then
        echo "$name: unchanged ($old)"
        return
      fi
      nix build --no-link --print-build-logs ".#$name" || return 1
      echo "$name: $old -> $new"
    }

    failed=()
    for name in "''${names[@]}"; do
      update_one "$name" || failed+=("$name")
    done

    # Not the store path of update-docs: the docs come from the bumped tree.
    nix run .#update-docs

    if [ ''${#failed[@]} -gt 0 ]; then
      echo "update: failed: ''${failed[*]}" >&2
      exit 1
    fi
  '';
}
