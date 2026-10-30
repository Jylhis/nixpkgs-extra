# Every packages/<name>/package.nix, called from one scope that holds all of
# them plus a few helpers, so a package asks for another (or for `fenix`) by
# naming it as an argument.
{
  pkgs,
  # The overlay passes prev.lib: the package names below must be computable
  # without `final`, whose attribute set depends on them.
  lib ? pkgs.lib,
  fenix ? null,
  extraLib,
}:
let

  # Built for other packages here, never exported: they would shadow nixpkgs
  # attributes or are helpers (haxe-lib; haxe-hxcpp, also used by
  # overrides/haxePackages.nix). Static, because the overlay must know the
  # attribute names without evaluating any package.
  internal = [
    "libwebsockets_4_5"
    "haxe-lib"
    "haxe-hxcpp"
  ];

  names = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./.));

  scope = lib.makeScope pkgs.newScope (
    self:
    {
      inherit fenix;
      # nixpkgs' lib with this repo's maintainers merged in, so package meta
      # reads `with lib.maintainers; [ jylhis ]` as it would upstream.
      lib = lib.extend (
        _: prev: {
          maintainers = prev.maintainers // extraLib.maintainers;
        }
      );
    }
    // lib.genAttrs names (name: self.callPackage (./. + "/${name}/package.nix") { })
  );
in
{
  inherit scope;
  packages = lib.genAttrs (lib.subtractLists internal names) (name: scope.${name});
}
