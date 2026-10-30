# haxePackages with hxcpp 4.3.171 (nixpkgs has 4.1.15, too old for lime 8.x).
#
# The build is packages/haxe-hxcpp, which haxe-lime uses directly, so the
# packages here work with or without this overlay.
{ final, prev }:
prev.haxePackages
// {
  hxcpp = final.callPackage ../packages/haxe-hxcpp/package.nix {
    haxe-lib = final.callPackage ../packages/haxe-lib/package.nix { };
  };
}
