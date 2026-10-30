# Non-flake entry point; flake.nix wraps it. Without arguments it uses the
# nixpkgs and fenix revisions pinned in flake.lock.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  fetchLocked =
    name:
    let
      node = lock.nodes.${name}.locked;
    in
    builtins.fetchTarball {
      url = "https://github.com/${node.owner}/${node.repo}/archive/${node.rev}.tar.gz";
      sha256 = node.narHash;
    };
in
{
  system ? builtins.currentSystem,
  pkgs ? import (fetchLocked "nixpkgs") { inherit system; },
  fenix ? import (fetchLocked "fenix") { inherit pkgs; },
  # fenix for another system; modules and the overlay build against the
  # consumer's pkgs, which need not be `system`.
  fenixFor ? _: fenix,
}:
let
  inherit (pkgs) lib;

  extraLib = import ./lib { inherit lib; };

  packagesFor =
    pkgs:
    import ./packages {
      inherit pkgs extraLib;
      fenix = fenixFor pkgs.stdenv.hostPlatform.system;
    };

  packageSet = packagesFor pkgs;

  overrideSet = import ./overrides { inherit lib; };
  overriddenPkgs = pkgs.extend overrideSet.overlay;

  # Every module gets this repo's packages, built against the module's own
  # pkgs, as `extraPkgs`, so `package` options have a default without the
  # overlay. The key deduplicates it when several of our modules are imported.
  common = {
    key = "nixpkgs-extra/common";
    imports = [
      (
        { pkgs, ... }:
        {
          _module.args = {
            extraPkgs = (packagesFor pkgs).packages;
            inherit extraLib;
          };
        }
      )
    ];
  };

  discover =
    kind:
    let
      dir = ./modules + "/${kind}";
      names = lib.optionals (builtins.pathExists dir) (
        lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir))
      );
      modules = lib.genAttrs names (name: {
        key = "nixpkgs-extra/${kind}/${name}";
        imports = [
          common
          (dir + "/${name}")
        ];
      });
    in
    modules // { default.imports = lib.attrValues modules; };
in
{
  lib = extraLib;
  inherit (packageSet) packages;
  # Only for callPackage-style access to internal helpers and tests.
  inherit (packageSet) scope;
  nixosModules = discover "nixos";
  homeModules = discover "home";
  # The overridden nixpkgs attributes, for checks and docs; consumers apply
  # overlays.overrides instead.
  overrides = lib.genAttrs overrideSet.names (name: overriddenPkgs.${name});
  overlays = {
    default = import ./overlays { inherit fenixFor; };
    overrides = import ./overlays/overrides.nix;
    # Needs numtide/llm-agents.nix's overlays.shared-nixpkgs applied first.
    llm-agents = import ./overlays/llm-agents.nix;
  };
}
