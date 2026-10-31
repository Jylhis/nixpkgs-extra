# A lime app built for native Linux: haxe -> C++ via hxcpp, linked against
# lime.ndll. Running it on SDL's dummy video driver proves lime.ndll loads with
# its patched RUNPATH; no window opens, so it stays headless.
{
  lib,
  stdenv,
  haxe-lime,
}:
stdenv.mkDerivation {
  name = "haxe-lime-hello";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./project.xml
      ./Source
    ];
  };

  nativeBuildInputs = [ haxe-lime ];

  buildPhase = ''
    runHook preBuild
    export HOME=$TMPDIR
    export HXCPP_COMPILE_THREADS=$NIX_BUILD_CORES
    lime build linux -release -nocolor
    runHook postBuild
  '';

  # hxcpp resolves lime.ndll from the working directory, hence the cd. The app
  # keeps polling for a window after the failure, so timeout ends it.
  doCheck = true;
  checkPhase = ''
    runHook preCheck
    (cd Export/linux/bin && SDL_VIDEODRIVER=dummy timeout 20 ./LimeHello > $TMPDIR/run.log 2>&1) || true
    cat $TMPDIR/run.log
    grep "Hello from lime" $TMPDIR/run.log
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    touch $out
    runHook postInstall
  '';

  meta.platforms = haxe-lime.meta.platforms;
}
