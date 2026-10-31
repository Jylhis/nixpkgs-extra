# `nix flake check` set:
#   pkgs-<name>              every package builds and has an FHS-like $out
#   pkgs-<name>-<test>       every derivation in a package's passthru.tests
#   nixos-<name>, home-<name> modules/<kind>/<name>/test.nix (eval tests)
#   vm-<name>                modules/nixos/<name>/vm-test.nix (x86_64-linux only:
#                            GitHub's arm runners have no KVM)
#   override-<name>          every overrides/<name>.nix builds
#   llm-agents-override-<name> every llm-agents-overrides/<name>.nix builds
#   llm-agents-ocr-git-path  ocr wrapper puts the pinned git first on PATH
#   the rest                 repo-wide lints in this directory
{
  pkgs,
  repo,
  packages,
  repoWith,
  home-manager,
  llm-agents,
}:
let
  inherit (pkgs) lib;

  callCheck =
    file:
    import file {
      inherit
        pkgs
        repo
        repoWith
        home-manager
        llm-agents
        ;
    };

  testLib = import ./lib.nix { inherit pkgs home-manager; };

  packageChecks = lib.mapAttrs' (
    name: pkg: lib.nameValuePair "pkgs-${name}" (import ./fhs-layout.nix { inherit pkgs; } name pkg)
  ) packages;

  packageTests = lib.concatMapAttrs (
    name: pkg:
    lib.mapAttrs' (test: drv: lib.nameValuePair "pkgs-${name}-${test}" drv) (
      lib.filterAttrs (
        _: drv: lib.isDerivation drv && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
      ) (pkg.passthru.tests or { })
    )
  ) packages;

  moduleTests =
    kind: file: prefix:
    let
      dir = ../modules + "/${kind}";
      names = lib.optionals (builtins.pathExists dir) (
        lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))
      );
      withTest = lib.filter (name: builtins.pathExists (dir + "/${name}/${file}")) names;
    in
    lib.listToAttrs (
      map (
        name:
        lib.nameValuePair "${prefix}-${name}" (
          import (dir + "/${name}/${file}") {
            inherit pkgs lib testLib;
            inherit (repo) nixosModules homeModules;
            extraLib = repo.lib;
            module = repo."${kind}Modules".${name};
          }
        )
      ) withTest
    );

  # Skipped while nixpkgs' own attribute fails to evaluate (marked broken, or
  # a broken dependency): that is upstream's to fix, not the override's.
  # Errors in the override itself still fail.
  upstreamEvaluates = name: (builtins.tryEval (pkgs.${name}.drvPath or null)).success;

  # An override that returns a package set (grafanaPlugins, haxePackages) is
  # not a derivation: check the members it adds or replaces instead, built as
  # override-<set>-<member>.
  overrideChecks =
    let
      buildable = lib.filterAttrs (
        name: drv: upstreamEvaluates name && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
      ) repo.overrides;

      changedMembers =
        name: set:
        lib.filterAttrs (
          member: drv:
          lib.isDerivation drv
          && lib.meta.availableOn pkgs.stdenv.hostPlatform drv
          && drv.drvPath != (pkgs.${name}.${member} or { drvPath = null; }).drvPath
        ) set;
    in
    lib.concatMapAttrs (
      name: value:
      if lib.isDerivation value then
        { "override-${name}" = value; }
      else
        lib.mapAttrs' (member: drv: lib.nameValuePair "override-${name}-${member}" drv) (
          changedMembers name value
        )
    ) buildable;

  # pkgs.llm-agents as a consumer sees it, before and after our overlay.
  llmAgentsPkgs = pkgs.extend llm-agents.overlays.shared-nixpkgs;
  llmAgentsOverridden = llmAgentsPkgs.extend repo.overlays.llm-agents;
  llmAgentsUpstreamEvaluates =
    name: (builtins.tryEval llmAgentsPkgs.llm-agents.${name}.drvPath).success;

  llmAgentsOverrideChecks = lib.listToAttrs (
    map (name: lib.nameValuePair "llm-agents-override-${name}" llmAgentsOverridden.llm-agents.${name}) (
      lib.filter (
        name:
        llmAgentsPkgs.llm-agents ? ${name}
        && llmAgentsUpstreamEvaluates name
        && lib.meta.availableOn pkgs.stdenv.hostPlatform llmAgentsOverridden.llm-agents.${name}
      ) (import ../llm-agents-overrides { inherit lib; }).names
    )
  );

  vmTests = lib.optionalAttrs (pkgs.stdenv.hostPlatform.system == "x86_64-linux") (
    moduleTests "nixos" "vm-test.nix" "vm"
  );
in
packageChecks
// packageTests
// overrideChecks
// llmAgentsOverrideChecks
// moduleTests "nixos" "test.nix" "nixos"
// moduleTests "home" "test.nix" "home"
// vmTests
// {
  meta-completeness = callCheck ./meta-completeness.nix;
  meta-style = callCheck ./meta-style.nix;
  check-meta = callCheck ./check-meta.nix;
  maintainers = callCheck ./maintainers.nix;
  module-options = callCheck ./module-options.nix;
  no-nixpkgs-clash = callCheck ./no-nixpkgs-clash.nix;
  overrides-target-exists = callCheck ./overrides-target-exists.nix;
  llm-agents-target-exists = callCheck ./llm-agents-target-exists.nix;
  llm-agents-ocr-git-path = callCheck ./llm-agents-ocr-git-path.nix;
  overlay = callCheck ./overlay.nix;
  ast-grep = callCheck ./ast-grep.nix;
  format = callCheck ./format.nix;
  docs-current = callCheck ./docs-current.nix;
}
