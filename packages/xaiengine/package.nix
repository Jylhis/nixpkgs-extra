# AI Engine runtime driver (aie-rt), used by dynamic-dispatch to build NPU
# transactions. Adapted from robcohen/nixpkgs branch vitis-ai (MIT), rev
# 9233c639, pkgs/by-name/xa/xaiengine. The pin is a commit on
# release/main_aig, so updates follow that branch; main-aie has diverged from
# it, and the xilinx_v* release tags are for the embedded (Versal) driver,
# so the version regex keeps nix-update from using them as the base version.
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
  version = "0-unstable-2026-01-07";

  src = fetchFromGitHub {
    owner = "Xilinx";
    repo = "aie-rt";
    rev = "8849e208bdcc533b20a0ed3f95c1ce961dee9c3a";
    hash = "sha256-CiczNOcjsRd+163gRqGpjNW9ap/6ntHNV8ImkLssWts=";
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
      extraArgs = [
        "--version=branch=release/main_aig"
        "--version-regex=(0-unstable-.*)"
      ];
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
