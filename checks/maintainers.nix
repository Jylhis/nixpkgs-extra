# lib/maintainers.nix entries in the shape nixpkgs accepts
# (lib/tests/maintainer-module.nix, maintainers/README.md), so one can move
# to maintainer-list.nix unchanged.
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;

  allowedKeys = [
    "name"
    "email"
    "github"
    "githubId"
    "matrix"
    "keys"
  ];

  checkMaintainer =
    handle: m:
    let
      unknown = lib.subtractLists allowedKeys (lib.attrNames m);
      problems =
        lib.optional (!lib.isString (m.name or null)) "name is not a string"
        ++ lib.optional (!lib.isString (m.github or null)) "github is not a string"
        ++ lib.optional (!lib.isInt (m.githubId or null)) "githubId is not an int"
        ++ lib.optional (lib.hasSuffix "noreply.github.com" (
          m.email or ""
        )) "email is a GitHub noreply address"
        ++ lib.optional (unknown != [ ]) "unknown keys ${lib.concatStringsSep ", " unknown}";
    in
    map (problem: "${handle}: ${problem}") problems;

  problems = lib.concatLists (lib.mapAttrsToList checkMaintainer repo.lib.maintainers);
in
if problems != [ ] then
  throw ("Invalid maintainers:\n" + lib.concatStringsSep "\n" problems)
else
  # Evaluation sorts attribute names, so the file order is checked on the text.
  pkgs.runCommand "maintainers" { } ''
    grep -oE '^  [A-Za-z0-9_-]+ = \{' ${../lib/maintainers.nix} | LC_ALL=C sort -cf
    touch $out
  ''
