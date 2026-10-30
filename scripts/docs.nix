# Generated documentation: the README package and override lists (nixpkgs
# and llm-agents) and the module option references. `nix run .#update-docs`
# writes them; checks/docs-current.nix fails when the committed copies are
# stale.
{ pkgs, repo }:
let
  inherit (pkgs) lib;
  root = toString ../.;

  # Option declarations point into the store; show repo-relative paths.
  relativeDeclarations =
    opt:
    opt
    // {
      declarations = map (
        decl:
        let
          s = toString decl;
          rel = lib.removePrefix "/" (lib.removePrefix root s);
        in
        if lib.hasPrefix root s then
          {
            name = "<nixpkgs-extra/${rel}>";
            url = "https://github.com/Jylhis/nixpkgs-extra/blob/main/${rel}";
          }
        else
          decl
      ) opt.declarations;
    };

  optionsDoc =
    modules:
    (pkgs.nixosOptionsDoc {
      options =
        builtins.removeAttrs
          (lib.evalModules {
            modules = modules ++ [
              {
                _module.check = false;
                _module.args.pkgs = pkgs;
              }
            ];
          }).options
          [ "_module" ];
      documentType = "none";
      warningsAreErrors = false;
      transformOptions = relativeDeclarations;
    }).optionsCommonMark;

  without = attrs: lib.attrValues (builtins.removeAttrs attrs [ "default" ]);

  # One bullet per package, grouped by passthru.category.
  packageList =
    let
      byCategory = lib.groupBy (p: p.category) (
        lib.mapAttrsToList (name: pkg: {
          inherit name;
          category = pkg.passthru.category or "Other";
          inherit (pkg.meta) description homepage;
        }) repo.packages
      );
      entry =
        p: "- [`${p.name}`](packages/${p.name}/package.nix): ${p.description} ([homepage](${p.homepage}))";
      section = category: ''
        ### ${category}

        ${lib.concatMapStringsSep "\n" entry byCategory.${category}}
      '';
    in
    lib.concatMapStringsSep "\n" section (lib.attrNames byCategory);

  # One bullet per overrides/<attr>.nix and llm-agents-overrides/<attr>.nix,
  # described by its first comment line.
  overrideEntries =
    dir: prefix:
    lib.mapAttrsToList (
      name: description: "- [`${prefix}${name}`](${dir}/${name}.nix): ${description}"
    ) (import (../. + "/${dir}") { inherit lib; }).descriptions;
  overrideList =
    lib.concatStringsSep "\n" (
      overrideEntries "overrides" "" ++ overrideEntries "llm-agents-overrides" "llm-agents."
    )
    + "\n";
in
{
  nixosOptions = optionsDoc (without repo.nixosModules);
  homeOptions = optionsDoc (without repo.homeModules);
  packageList = pkgs.writeText "package-list.md" packageList;
  overrideList = pkgs.writeText "override-list.md" overrideList;
}
