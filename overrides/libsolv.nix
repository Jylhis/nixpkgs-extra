# libsolv with Debian repository support (deb2solv, testcase Debian solving).
#
# nixpkgs builds the RPM and conda backends only.
{ prev, ... }:
prev.libsolv.overrideAttrs (old: {
  cmakeFlags = old.cmakeFlags ++ [ (prev.lib.cmakeBool "ENABLE_DEBIAN" true) ];
})
