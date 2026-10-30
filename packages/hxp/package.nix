# hxp: the build-script library lime's command-line tools are written against.
# Installed from the tagged source. The committed run.n (`haxelib run hxp`) is
# kept: scripts/run.hxml at this tag imports a hxp.InterpHelper the tree does
# not contain, so it cannot be rebuilt.
{
  lib,
  fetchFromGitHub,
  haxe-lib,
  nix-update-script,
}:
haxe-lib.buildHaxeLib rec {
  libname = "hxp";
  version = "1.3.1";

  src = fetchFromGitHub {
    owner = "openfl";
    repo = "hxp";
    tag = version;
    hash = "sha256-vrQUNC2q+diYwd1sE5AZan3D6oMdBCCANXgooqbKmio=";
  };

  dontBuild = true;

  passthru = {
    category = "Developer tools";
    library = true;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Cross-platform build tools for desktop, mobile, web and consoles";
    homepage = "https://github.com/openfl/hxp";
    changelog = "https://github.com/openfl/hxp/blob/${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    # run.n is prebuilt bytecode (see above); bin/ ships upstream helper
    # binaries and jars (webify, closure compiler, yuicompressor, ios-deploy)
    # used by non-Linux targets. Both are installed as-is.
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
      binaryBytecode
    ];
    platforms = lib.platforms.unix;
    maintainers = with lib.maintainers; [ jylhis ];
  };
}
