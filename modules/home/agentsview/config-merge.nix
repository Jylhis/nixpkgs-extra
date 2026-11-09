# The only writer of agentsview's config.toml besides agentsview itself. It
# takes the flock agentsview uses, so a merge never interleaves with the
# daemon's own save.
#
# Usage: agentsview-config-merge CONFIG SETTINGS.json
# Replaces each top-level table named in SETTINGS.json wholesale and keeps
# every other key. Prints "changed" when it rewrote the file, so activation
# can restart the daemon (it reads config.toml only at start). DRY_RUN=1
# touches nothing, not even the directory or the lock file.
{ pkgs }:
pkgs.writeShellApplication {
  name = "agentsview-config-merge";
  runtimeInputs = [
    pkgs.remarshal
    pkgs.jq
    pkgs.util-linux
    pkgs.coreutils
  ];
  text = ''
    conf=$1
    settings=$2
    if [ -n "''${DRY_RUN:-}" ]; then
      exit 0
    fi
    (umask 077; mkdir -p "$(dirname "$conf")")
    # Append mode: opening the lock must not truncate agentsview's file.
    exec 9>>"$conf.lock"
    # Bounded: a wedged agentsview must not hang the whole activation.
    flock -w 60 9

    if [ -s "$conf" ]; then
      current=$(remarshal -if toml -of json "$conf")
    else
      current='{}'
    fi
    # Replace each managed table wholesale so a key dropped from Nix also
    # disappears from the file.
    merged=$(printf '%s' "$current" | jq --slurpfile s "$settings" \
      'reduce ($s[0] | keys[]) as $k (.; .[$k] = $s[0][$k])')

    # mktemp creates both files 0600, and a unique sibling cannot inherit
    # the mode of a stale temp file the way a fixed name would.
    json=$(mktemp)
    out=$(mktemp "$conf.XXXXXX")
    trap 'rm -f "$json" "$out"' EXIT
    printf '%s' "$merged" > "$json"
    remarshal -if json -of toml "$json" > "$out"
    if [ -e "$conf" ] && cmp -s "$out" "$conf"; then
      chmod 600 "$conf"
      exit 0
    fi
    mv "$out" "$conf"
    echo changed
  '';
}
