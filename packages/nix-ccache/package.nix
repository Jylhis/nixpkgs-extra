# ccache wrapper with a fixed cache directory for sandboxed Nix builds.
{
  lib,
  stdenv,
  ccache,
  cacheDir ? "/var/cache/ccache",
}:
stdenv.mkDerivation {
  pname = "nix-ccache";
  inherit (ccache) version;

  src = ./nix-ccache.c;
  dontUnpack = true;

  buildPhase = ''
    runHook preBuild
    $CC -O2 -Wall -Werror -o nix-ccache $src \
      -DCCACHE='"${ccache}/bin/ccache"' -DCACHE_DIR='"${cacheDir}"'
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 nix-ccache $out/bin/nix-ccache
    runHook postInstall
  '';

  passthru.category = "Developer tools";

  meta = {
    description = "ccache wrapper with a fixed cache directory for sandboxed Nix builds";
    homepage = "https://github.com/Jylhis/nixpkgs-extra/tree/main/packages/nix-ccache";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "nix-ccache";
    platforms = lib.platforms.linux;
  };
}
