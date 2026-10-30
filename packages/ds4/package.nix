# ds4: DeepSeek V4 inference engine with a ROCm backend. Upstream supports
# only the Strix Halo target (gfx1151) today; `gpuTarget` overrides it.
# Adapted from noamsto/nix-amd-ai (MIT), rev fd140e8, pkgs/ds4.
{
  lib,
  stdenv,
  fetchFromGitHub,
  rocmPackages,
  nix-update-script,
  gpuTarget ? "gfx1151",
}:
stdenv.mkDerivation (_finalAttrs: {
  pname = "ds4";
  version = "0-unstable-2026-06-17";

  # Upstream publishes no tags, so the commit is pinned.
  src = fetchFromGitHub {
    owner = "antirez";
    repo = "ds4";
    rev = "80ebbc396aee40eedc1d829222f3362d10fa4c6c";
    hash = "sha256-Ieuc72GHZs20ModQfnvI5Me31n4Pj+WFYtsuqaKJceo=";
  };

  # clr ships the hipcc wrapper (+ amdclang++) and the HIP runtime headers.
  nativeBuildInputs = [ rocmPackages.clr ];

  buildInputs = [
    rocmPackages.hipblas
    rocmPackages.hipblas-common
    rocmPackages.hipblaslt
    rocmPackages.hipcub
    rocmPackages.rocprim
    rocmPackages.rocwmma
  ];

  makeFlags = [
    "strix-halo"
    "HIPCC=hipcc"
    "ROCM_ARCH=${gpuTarget}"
    # Upstream hardcodes -march=native; pin a portable baseline so the binary
    # is cacheable (the GPU offload arch, not the host CPU, is what matters).
    "NATIVE_CPU_FLAG=-march=x86-64-v3"
  ];

  # clr's hipcc does not consume Nix's include/lib search paths, so point it
  # at the ROCm math libraries explicitly.
  env = {
    ROCM_PATH = "${rocmPackages.clr}";
    HIPCC_COMPILE_FLAGS_APPEND = toString [
      "-I${rocmPackages.rocwmma}/include"
      "-I${rocmPackages.hipblaslt}/include"
      "-I${rocmPackages.hipblas}/include"
      "-I${rocmPackages.hipblas-common}/include"
      "-I${rocmPackages.hipcub}/include"
      "-I${rocmPackages.rocprim}/include"
    ];
    HIPCC_LINK_FLAGS_APPEND = toString [
      "-L${rocmPackages.hipblas}/lib"
      "-L${rocmPackages.hipblaslt}/lib"
      "-Wl,-rpath,${rocmPackages.hipblas}/lib"
      "-Wl,-rpath,${rocmPackages.hipblaslt}/lib"
    ];
  };

  enableParallelBuilding = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 -t $out/bin ds4 ds4-server ds4-bench ds4-eval ds4-agent
    runHook postInstall
  '';

  passthru = {
    category = "AI tools";
    updateScript = nix-update-script {
      extraArgs = [ "--version=branch" ];
    };
  };

  meta = {
    description = "Native DeepSeek V4 inference engine with a Strix Halo ROCm backend";
    homepage = "https://github.com/antirez/ds4";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "ds4";
    platforms = [ "x86_64-linux" ];
  };
})
