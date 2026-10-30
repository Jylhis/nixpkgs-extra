# lime 8.x built from source: the haxelib zip ships a prebuilt lime.ndll. The
# steps mirror upstream CI (linux job): build the CLI tools with -nocffi, then
# `lime rebuild linux -64 -release` to produce ndll/Linux64/lime.ndll.
#
# SDL and OpenAL Soft dlopen X11/GL/ALSA/PulseAudio at runtime, so the headers
# are build inputs and the shared objects go onto the ndll's RUNPATH.
#
# hxcpp comes from haxe-hxcpp (4.3.x): lime 8.x needs it and nixpkgs has
# 4.1.15 unless overlays.overrides is applied.
{
  lib,
  fetchFromGitHub,
  nix-update-script,
  coreutils,
  haxe,
  neko,
  haxePackages,
  haxe-lib,
  haxe-hxcpp,
  hxp,
  alsa-lib,
  libGL,
  libGLU,
  libpulseaudio,
  libx11,
  libxext,
  libxi,
  libxinerama,
  libxrandr,
  libxrender,
  xorgproto,
}:
let
  inherit (haxe-lib) buildHaxeLib withCommas;
  inherit (haxePackages) format;

  # Upstream's lime.ndll for each platform; only Linux x86_64 is wired so far.
  rebuildTarget = "linux -64";
  ndllDir = "ndll/Linux64";

  runtimeLibs = [
    alsa-lib
    libGL
    libpulseaudio
    libx11
    libxext
    libxi
    libxinerama
    libxrandr
  ];

  haxeDeps = [
    format
    haxe-hxcpp
    hxp
  ];
in
buildHaxeLib rec {
  libname = "lime";
  version = "8.3.2";

  src = fetchFromGitHub {
    owner = "openfl";
    repo = "lime";
    tag = version;
    fetchSubmodules = true;
    hash = "sha256-wpLLNKml8lxJFeNTCwTbEOqq/2YJwZiB9WToLgVzx5w=";
  };

  buildInputs = runtimeLibs ++ [
    libGLU
    libxrender
    xorgproto
  ];

  propagatedBuildInputs = haxeDeps;

  # Throwaway haxelib repository: dependencies by symlink, lime as a dev
  # checkout of this tree (what `haxelib dev lime .` writes).
  configurePhase = ''
    runHook preConfigure
    export HOME=$TMPDIR
    export HAXELIB_PATH=$TMPDIR/haxelib
    mkdir -p "$HAXELIB_PATH/lime"
    ${lib.concatMapStringsSep "\n" (d: ''ln -s ${d}/lib/haxe/* "$HAXELIB_PATH"/'') haxeDeps}
    echo -n "$PWD" > "$HAXELIB_PATH/lime/.dev"
    export HXCPP_COMPILE_THREADS=$NIX_BUILD_CORES
    runHook postConfigure
  '';

  # Recompile run.n and tools/tools.n rather than trust committed bytecode.
  buildPhase = ''
    runHook preBuild
    rm -f run.n tools/tools.n
    (cd tools && haxe run.hxml && haxe tools.hxml)
    haxelib run lime rebuild ${rebuildTarget} -release -nocolor -verbose -nocffi
    test -f ${ndllDir}/lime.ndll
    runHook postBuild
  '';

  # Drop the native build inputs (~400 MiB); unused once lime.ndll exists.
  preInstall = ''
    rm -rf project/lib project/obj
  '';

  postInstall = ''
    libdir=$out/lib/haxe/lime/${withCommas version}
    patchelf --add-rpath ${lib.makeLibraryPath runtimeLibs} "$libdir/${ndllDir}/lime.ndll"

    # Single-directory repository the `lime` wrapper points HAXELIB_PATH at.
    repo=$out/share/lime/haxelib
    mkdir -p "$repo"
    ln -s "$out/lib/haxe/lime" "$repo/lime"
    ${lib.concatMapStringsSep "\n" (d: ''ln -s ${d}/lib/haxe/* "$repo"/'') haxeDeps}

    # The /usr/bin/env shebang is rewritten by patchShebangs in fixupPhase.
    mkdir -p $out/bin
    substitute ${./lime.sh} $out/bin/lime \
      --subst-var-by repo "$repo" \
      --subst-var-by haxebin ${haxe}/bin \
      --subst-var-by nekobin ${neko}/bin \
      --subst-var-by haxelib ${haxe}/bin/haxelib \
      --subst-var-by mktemp ${coreutils}/bin/mktemp \
      --subst-var-by rm ${coreutils}/bin/rm \
      --subst-var-by ln ${coreutils}/bin/ln
    chmod +x $out/bin/lime
  '';

  # shrink-rpath would drop the dlopen-only RUNPATH entries added above.
  dontPatchELF = true;

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/lime help > lime-help.txt
    grep "Lime Command-Line Tools" lime-help.txt
    runHook postInstallCheck
  '';

  passthru = {
    inherit haxeDeps;
    category = "Developer tools";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Foundational Haxe framework for cross-platform native and web development";
    homepage = "https://lime.openfl.org/";
    changelog = "https://github.com/openfl/lime/blob/${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    # templates/ and dependencies/ still carry upstream's prebuilt binaries for
    # other targets (Windows exes, Android jars, hxswfml.n, svg.n).
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
      binaryBytecode
    ];
    mainProgram = "lime";
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ jylhis ];
  };
}
