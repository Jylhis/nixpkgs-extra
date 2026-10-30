# The metadata every public package must declare (AGENTS.md, Package
# metadata). Libraries without an executable set passthru.library = true and
# skip meta.mainProgram.
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;

  checkPackage =
    name: pkg:
    let
      meta = pkg.meta or { };
      library = pkg.passthru.library or false;
      missing =
        lib.optional (!(meta ? description)) "meta.description"
        ++ lib.optional (!(meta ? homepage)) "meta.homepage"
        ++ lib.optional (!(meta ? license)) "meta.license"
        ++ lib.optional ((meta.maintainers or [ ]) == [ ]) "meta.maintainers"
        ++ lib.optional (!(meta ? platforms)) "meta.platforms"
        ++ lib.optional ((meta.sourceProvenance or [ ]) == [ ]) "meta.sourceProvenance"
        ++ lib.optional (!library && !(meta ? mainProgram)) "meta.mainProgram"
        ++ lib.optional (!(pkg.passthru ? category)) "passthru.category";
    in
    lib.optional (missing != [ ]) "${name}: missing ${lib.concatStringsSep ", " missing}";

  problems = lib.concatLists (lib.mapAttrsToList checkPackage repo.packages);
in
if problems != [ ] then
  throw ("Incomplete package metadata:\n" + lib.concatStringsSep "\n" problems)
else
  pkgs.runCommand "meta-completeness" { } "touch $out"
