# AI Engine runtime driver (aie-rt), used by dynamic-dispatch to build NPU
# transactions. Adapted from robcohen/nixpkgs branch vitis-ai (MIT), rev
# 9233c639, pkgs/by-name/xa/xaiengine. The pin is a commit on
# release/main_aig, so updates follow that branch; main-aie has diverged from
# it, and the xilinx_v* release tags are for the embedded (Versal) driver.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  cmake,
  ninja,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "xaiengine";
  version = "3.8-unstable-2024-10-08";

  src = fetchFromGitHub {
    owner = "Xilinx";
    repo = "aie-rt";
    rev = "4a012d7932155217d2c9368a3588a3c41d2b9edb";
    hash = "sha256-nI8RZod53HYfo1GEJYu0pOOWUHrG3+jGh2etmDl//eY=";
  };

  sourceRoot = "${finalAttrs.src.name}/driver";

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeBool "WITH_TESTS" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-quiet '-Werror' ""
  '';

  passthru = {
    category = "AMD NPU";
    library = true;
    updateScript = nix-update-script {
      extraArgs = [ "--version=branch=release/main_aig" ];
    };
  };

  meta = {
    description = "AMD AI Engine runtime driver library";
    homepage = "https://github.com/Xilinx/aie-rt";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
})
