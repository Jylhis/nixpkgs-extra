# vLLM with the ROCm backend for AMD Strix APUs (gfx1150, gfx1151),
# repackaged from the lemonade-sdk/vllm-rocm prebuilt (portable TheRock ROCm,
# torch and vLLM): nixpkgs' rocmPackages lag ROCm 7.15 and lack the Strix
# gfx targets. Adapted from noamsto/nix-amd-ai (MIT); see
# noamsto/nix-amd-ai#63.
#
# Deliberately not autoPatchelf'd: the bundle is self-contained, and
# autoPatchelfHook would inject nixpkgs libstdc++/libatomic that do not match
# the Ubuntu-built torch, which then segfaults on `import torch`. Only the ELF
# interpreter is repointed; the launcher's LD_LIBRARY_PATH supplies libstdc++
# and libz.
#
# No update script: see sources.nix.
{
  lib,
  stdenv,
  fetchurl,
  patchelf,
  makeWrapper,
  bash,
  coreutils,
  zlib,
  gpuTarget ? "gfx1150",
}:
let
  sources = import ./sources.nix;
  src =
    sources.${gpuTarget}
      or (throw "vllm-rocm: no prebuilt for gpuTarget '${gpuTarget}' (have: ${lib.concatStringsSep ", " (lib.attrNames sources)})");
  parts = map (p: fetchurl { inherit (p) url hash; }) src.parts;
  # Ubuntu-built torch/ROCm want these from the system; the bundle omits them.
  runtimeLibs = lib.makeLibraryPath [
    stdenv.cc.cc.lib
    zlib
  ];
in
stdenv.mkDerivation {
  pname = "vllm-rocm";
  inherit (src) version;

  # Two <2 GB GitHub assets that concatenate into one .tar.gz.
  srcs = parts;

  nativeBuildInputs = [
    patchelf
    makeWrapper
  ];

  # Unpack into a subdirectory: $NIX_BUILD_TOP holds Nix's env-vars, which
  # would drag the source parts and stdenv into the closure.
  unpackPhase = ''
    runHook preUnpack
    mkdir source
    cat ${lib.concatStringsSep " " parts} | tar xz -C source
    sourceRoot=source
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    prefix=$out/opt/vllm-rocm
    mkdir -p $prefix
    cp -r bin include lib share $prefix/

    # Upstream tars the venv without exec bits. Also pre-mark the bundled
    # clang: the launcher's runtime chmod silently no-ops on the store.
    chmod -R u+x $prefix/bin
    for d in $prefix/lib/python3.*/site-packages/_rocm_sdk_*/bin \
             $prefix/lib/python3.*/site-packages/_rocm_sdk_*/lib/llvm/bin; do
      [ -d "$d" ] && chmod -R u+x "$d"
    done

    # Repoint the ELF interpreter on every executable in the bundle's bin
    # dirs (clang re-execs clang-N, torch shells out to ninja). Keep runpaths.
    loader=${stdenv.cc.bintools.dynamicLinker}
    for d in $prefix/bin \
             $prefix/lib/python3.*/site-packages/_rocm_sdk_*/bin \
             $prefix/lib/python3.*/site-packages/_rocm_sdk_*/lib/llvm/bin; do
      [ -d "$d" ] || continue
      for exe in "$d"/*; do
        if [ -f "$exe" ] && patchelf --print-interpreter "$exe" >/dev/null 2>&1; then
          patchelf --set-interpreter "$loader" "$exe"
        fi
      done
    done

    # Launcher shebang is #!/bin/bash (FHS); rewrite to the nix bash. Only
    # vllm-server is exposed, so the pip console scripts keep their shebang.
    patchShebangs $prefix/bin/vllm-server

    # auditwheel-repaired wheels carry an $ORIGIN RUNPATH to a sibling *.libs
    # dir that does not resolve reliably in the store; add them explicitly.
    auditLibs=""
    for d in $prefix/lib/python3.*/site-packages/*.libs; do
      [ -d "$d" ] && auditLibs="$auditLibs:$d"
    done

    # lemonade's vllm.rocm_bin points at $out/bin/vllm-server. The launcher
    # needs libstdc++/libz and coreutils from the system.
    mkdir -p $out/bin
    makeWrapper $prefix/bin/vllm-server $out/bin/vllm-server \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
        ]
      } \
      --prefix LD_LIBRARY_PATH : "${runtimeLibs}$auditLibs"
    runHook postInstall
  '';

  # Keep the bundle's long internal runpaths; shrinking them touches 587 files.
  dontStrip = true;
  dontPatchELF = true;

  # Keep the ~4 GB of source parts and the toolchain out of the closure.
  disallowedReferences = parts ++ [ stdenv.cc ];

  passthru = {
    category = "AMD NPU";
    inherit gpuTarget;
    gpuTargets = lib.attrNames sources;
  };

  meta = {
    description = "Prebuilt vLLM with the TheRock ROCm backend for AMD Strix APUs";
    homepage = "https://github.com/lemonade-sdk/vllm-rocm";
    changelog = "https://github.com/lemonade-sdk/vllm-rocm/releases/tag/${lib.escapeURL src.releaseTag}";
    # The packaging repo is MIT; the bundle carries vLLM (Apache 2.0), torch,
    # numpy and scipy (BSD-3), CPython (PSF), TheRock's LLVM (Apache 2.0 with
    # LLVM exception), ROCm device libs (NCSA) and Tcl/Tk.
    license = with lib.licenses; [
      mit
      asl20
      llvm-exception
      bsd3
      psfl
      ncsa
      tcltk
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "vllm-server";
    platforms = [ "x86_64-linux" ];
  };
}
