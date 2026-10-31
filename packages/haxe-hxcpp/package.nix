# hxcpp 4.3.x built from the tagged source. nixpkgs' haxePackages.hxcpp is the
# 4.1.15 zip, too old for lime 8.x, and 4.3.x is only released on GitHub as CI
# builds: hxcpp.n compiled with haxe, haxelib.json and include/HxcppVersion.h
# stamped with the version (tools/version/Write.hx upstream).
{
  lib,
  fetchFromGitHub,
  haxe-lib,
}:
haxe-lib.buildHaxeLib (finalAttrs: {
  libname = "hxcpp";
  version = "4.3.171";

  src = fetchFromGitHub {
    owner = "HaxeFoundation";
    repo = "hxcpp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-fRgn5Jne6RzkUZKUj78ESs79G2DLYp0Zqh7Iin5vTKA=";
  };

  postPatch = ''
    substituteInPlace haxelib.json \
      --replace-fail '"version": "4.3.0"' '"version": "${finalAttrs.version}"'
    printf '#ifndef HXCPP_VERSION\n#define HXCPP_VERSION "%s"\n#endif' \
      ${finalAttrs.version} > include/HxcppVersion.h
  '';

  # Rebuild both neko entry points rather than trust the committed run.n:
  # hxcpp.n would otherwise try to compile into the read-only store.
  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    (cd tools/run && haxe compile.hxml)
    (cd tools/hxcpp && haxe compile.hxml)
    runHook postBuild
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -f "$out/lib/haxe/hxcpp/${lib.replaceStrings [ "." ] [ "," ] finalAttrs.version}/hxcpp.n"
    runHook postInstallCheck
  '';

  meta = {
    description = "Runtime support library for the Haxe C++ backend";
    homepage = "https://github.com/HaxeFoundation/hxcpp";
    changelog = "https://github.com/HaxeFoundation/hxcpp/blob/v${finalAttrs.version}/Changes.md";
    # One-condition BSD (LICENSE.txt), i.e. BSD-1-Clause; haxelib.json says "BSD".
    license = lib.licenses.bsd1;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    platforms = lib.platforms.unix;
    maintainers = lib.optional (lib.maintainers ? jylhis) lib.maintainers.jylhis;
  };
})
