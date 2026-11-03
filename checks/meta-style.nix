# The style nixpkgs reviewers ask for in package metadata (pkgs/README.md,
# "Meta attributes" and "Package naming"). meta-completeness checks that the
# attributes exist; this checks what they say.
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;

  # Packages whose pname differs from the attribute name, and why.
  pnameExceptions = {
    haxe-lime = "buildHaxeLib sets pname to the haxelib name, lime";
    lemonade-server = "renamed for a nixpkgs clash; upstream's project name is lemonade";
    python-onnxruntime-vitisai = "the Python module of onnxruntime-vitisai, named after it";
  };

  matches = re: s: builtins.match re s != null;

  checkPackage =
    name: pkg:
    let
      meta = pkg.meta or { };
      description = meta.description or "";
      pname = pkg.pname or null;
      isStringIfSet = attr: !(meta ? ${attr}) || lib.isString meta.${attr};
      problems =
        lib.optional (!matches "[A-Z].*" description) "meta.description does not start with a capital"
        ++ lib.optional (matches "(The|An?) .*" description) "meta.description starts with an article"
        ++ lib.optional (matches ".*[[:punct:]]" description) "meta.description ends with punctuation"
        ++ lib.optional (
          pname != null && lib.hasPrefix (lib.toLower pname) (lib.toLower description)
        ) "meta.description starts with the package name"
        ++ lib.optional (
          pname != null && !matches "[a-z0-9_][a-z0-9_-]*" pname
        ) "pname ${pname} is not lowercase"
        ++ lib.optional (
          pname != null && pname != name && !(pnameExceptions ? ${name})
        ) "pname ${pname} differs from the attribute name"
        ++ lib.optional (!matches "[0-9].*" (pkg.version or "")) "version does not start with a digit"
        ++ map (attr: "meta.${attr} is not a string") (
          lib.filter (attr: !isStringIfSet attr) [
            "mainProgram"
            "homepage"
            "changelog"
          ]
        );
    in
    map (problem: "${name}: ${problem}") problems;

  stale = lib.filter (name: (repo.packages.${name}.pname or name) == name) (
    lib.attrNames pnameExceptions
  );

  problems =
    lib.concatLists (lib.mapAttrsToList checkPackage repo.packages)
    ++ map (name: "${name}: pnameExceptions entry no longer needed") stale;
in
if problems != [ ] then
  throw ("Package metadata style:\n" + lib.concatStringsSep "\n" problems)
else
  pkgs.runCommand "meta-style" { } "touch $out"
