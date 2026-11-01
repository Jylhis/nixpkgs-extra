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

  # strict: fail on an option without a description or a type, and evaluate
  # the modules against a pkgs that holds only lib and pkgs.formats, as
  # nixpkgs' sandboxed doc build does (nixos/lib/eval-cacheable-options.nix),
  # so a default that reads a package needs a defaultText.
  optionsDoc =
    {
      modules,
      strict ? false,
    }:
    pkgs.nixosOptionsDoc {
      options =
        builtins.removeAttrs
          (lib.evalModules {
            modules = modules ++ [
              {
                _module.check = false;
                _module.args.pkgs =
                  if strict then
                    import (pkgs.path + "/pkgs/pkgs-lib") {
                      inherit lib;
                      pkgs = null;
                    }
                    // {
                      inherit lib;
                    }
                  else
                    pkgs;
              }
            ];
          }).options
          [ "_module" ];
      documentType = "none";
      warningsAreErrors = strict;
      transformOptions = relativeDeclarations;
    };

  without = attrs: lib.attrValues (builtins.removeAttrs attrs [ "default" ]);

  # nixos-render-docs output depends on its job count (-j $NIX_BUILD_CORES):
  # with 1 or 2 jobs some descriptions gain blank lines. One job, so the
  # committed docs match on every builder.
  singleJob =
    drv:
    assert lib.hasInfix "-j $NIX_BUILD_CORES" drv.buildCommand;
    drv.overrideAttrs (old: {
      buildCommand = lib.replaceStrings [ "-j $NIX_BUILD_CORES" ] [ "-j 1" ] old.buildCommand;
    });

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
  nixosOptions = singleJob (optionsDoc { modules = without repo.nixosModules; }).optionsCommonMark;
  homeOptions = singleJob (optionsDoc { modules = without repo.homeModules; }).optionsCommonMark;
  # For checks/module-options.nix.
  strictOptions = {
    nixos = optionsDoc {
      modules = without repo.nixosModules;
      strict = true;
    };
    home = optionsDoc {
      modules = without repo.homeModules;
      strict = true;
    };
  };
  packageList = pkgs.writeText "package-list.md" packageList;
  overrideList = pkgs.writeText "override-list.md" overrideList;
}
