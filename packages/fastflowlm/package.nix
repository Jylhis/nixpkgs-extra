# FastFlowLM: NPU-optimized LLM runtime (XDNA-2 only, Strix Point / Strix
# Halo).
# Adapted from noamsto/nix-amd-ai (MIT), rev 5b82496, pkgs/fastflowlm.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  oniguruma,
  cmake,
  ninja,
  pkg-config,
  boost,
  curl,
  fftw,
  fftwFloat,
  fftwLongDouble,
  ffmpeg,
  readline,
  libedit,
  libuuid,
  libdrm,
  cargo,
  rustc,
  rustPlatform,
  autoPatchelfHook,
  xrt,
  nix-update-script,
}:
let
  # The build downloads these with ExternalProject, which the sandbox forbids.
  codecSources = {
    libjpeg_turbo = fetchurl {
      url = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz";
      hash = "sha256-bzAJLO+fuDl3lkZgj07hSuPLrJicR/oF6EGwhB8Jh44=";
    };
    libwebp = fetchurl {
      url = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz";
      hash = "sha256-5KtwCb8GKf0RmC1MKqg5ZM8kTP+6c0fs05AZqeOMRWQ=";
    };
    opus = fetchurl {
      url = "https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz";
      hash = "sha256-b/y1kyB76SWE3xWzJGbtZLvsmRCfAHyCIF8BlFckEaE=";
    };
    ogg = fetchurl {
      url = "https://github.com/xiph/ogg/releases/download/v1.3.6/libogg-1.3.6.tar.gz";
      hash = "sha256-g+ZwRzBoPQBNIOIbj39V3LM4PN+EwNrt8wveF193Rjg=";
    };
    vorbis = fetchurl {
      url = "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz";
      hash = "sha256-DpgkCanD/ILuBuCCBbE1XlxqpMNrylgUbvOZYhsM5as=";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "fastflowlm";
  version = "1.0.13";

  src = fetchFromGitHub {
    owner = "FastFlowLM";
    repo = "FastFlowLM";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4HFqZrHGo1Kpeyku6LRqWrDnrCb31fbhmBDVGRkdxDg=";
    fetchSubmodules = true;
  };

  cargoDeps = rustPlatform.importCargoLock {
    lockFile = ./Cargo.lock;
  };

  cargoRoot = "third_party/tokenizers-cpp/rust";

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    cargo
    rustc
    rustPlatform.cargoSetupHook
    autoPatchelfHook
  ];

  buildInputs = [
    boost
    curl
    fftw
    fftwFloat
    fftwLongDouble
    ffmpeg
    readline
    libedit
    oniguruma
    libuuid
    libdrm
    stdenv.cc.cc.lib
    xrt
  ];

  postPatch = ''
    # Cargo.lock is not committed upstream; inject our copy
    cp ${./Cargo.lock} third_party/tokenizers-cpp/rust/Cargo.lock

    substituteInPlace src/cmake/FlmImageCodecs.cmake \
      --replace-fail \
        'URL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/''${FLM_LIBJPEG_TURBO_VERSION}/libjpeg-turbo-''${FLM_LIBJPEG_TURBO_VERSION}.tar.gz' \
        'URL ${codecSources.libjpeg_turbo}' \
      --replace-fail \
        'URL https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-''${FLM_LIBWEBP_VERSION}.tar.gz' \
        'URL ${codecSources.libwebp}'
    substituteInPlace src/cmake/FlmAudioCodecs.cmake \
      --replace-fail 'URL ''${urls}' 'URL ''${FLM_SRC_''${name}}'
  '';

  dontUseCmakeConfigure = true;

  configurePhase = ''
    runHook preConfigure
    cmake -S src -B src/build \
      -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DFLM_VERSION="${finalAttrs.version}" \
      -DNPU_VERSION="32.0.203.304" \
      "-DXRT_INCLUDE_DIR=${xrt}/opt/xilinx/xrt/include" \
      "-DXRT_LIB_DIR=${xrt}/opt/xilinx/xrt/lib" \
      -DCMAKE_EXE_LINKER_FLAGS=-lonig \
      -DFLM_SRC_opus=${codecSources.opus} \
      -DFLM_SRC_ogg=${codecSources.ogg} \
      -DFLM_SRC_vorbis=${codecSources.vorbis} \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_XCLBIN_PREFIX=$out/share/flm
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    ninja -C src/build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    ninja -C src/build install
    runHook postInstall
  '';

  passthru = {
    category = "AMD NPU";
    # Cargo.lock is not committed upstream: regenerate it by hand on a bump.
    updateScript = nix-update-script { };
  };

  meta = {
    description = "NPU-optimized LLM runtime for AMD Ryzen AI";
    homepage = "https://github.com/FastFlowLM/FastFlowLM";
    changelog = "https://github.com/FastFlowLM/FastFlowLM/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
    # Builds xrt (slow): CI evaluates it but does not build it.
    hydraPlatforms = [ ];
    mainProgram = "flm";
  };
})
