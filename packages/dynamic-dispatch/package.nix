# Dynamic operator dispatch for AMD Ryzen AI: builds NPU transactions for ONNX
# operators on top of aie-rt (xaiengine) and XRT. Adapted from
# robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639,
# pkgs/by-name/dy/dynamic-dispatch. Upstream has no tags; the pin is the head
# of main.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  cmake,
  ninja,
  pkg-config,
  git,
  python3,
  protobuf,
  abseil-cpp,
  nlohmann_json,
  spdlog,
  zlib,
  libuuid,
  xaiengine,
  xrt,
}:

stdenv.mkDerivation {
  pname = "dynamic-dispatch";
  version = "0-unstable-2025-03-06";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "DynamicDispatch";
    rev = "b3051f03e20aab237cda3bbe4cd2081f76b72b06";
    hash = "sha256-kSRBn5ozQ6Ob/4qsRFvCQUHgnkqFASw/RUXQEJlGUdU=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    python3
    protobuf
  ];

  buildInputs = [
    protobuf
    abseil-cpp
    nlohmann_json
    spdlog
    zlib
    libuuid
    xaiengine
    xrt
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "ENABLE_DD_TESTS" false)
    (lib.cmakeBool "ENABLE_DD_PYTHON" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "DD_DISABLE_AIEBU" true)
    (lib.cmakeBool "DISABLE_LARGE_TXN_OPS" true)
    (lib.cmakeFeature "XRT_DIR" "${xrt}/opt/xilinx/xrt/share/cmake/XRT")
    (lib.cmakeFeature "CMAKE_PREFIX_PATH" "${xrt}/opt/xilinx/xrt")
    (lib.cmakeFeature "ZLIB_ROOT" "${zlib}")
  ];

  postPatch = ''
    # abseil (through protobuf's headers) needs C++20.
    find . \( -name CMakeLists.txt -o -name "*.cmake" \) -exec \
      sed -i -E 's/(set ?\(CMAKE_CXX_STANDARD) 17\)/\1 20)/; s/CXX_STANDARD 17\)/CXX_STANDARD 20)/' {} +

    # The build derives its version from git metadata.
    git init
    git config user.email "nix@build"
    git config user.name "Nix Build"
    git add -A
    git commit -m "Nix build" --allow-empty

    substituteInPlace cmake/zlib_dep.cmake \
      --replace-fail 'set(ZLIB_USE_STATIC_LIBS ON)' 'set(ZLIB_USE_STATIC_LIBS OFF)'

    # The pm_load op and the PM_LOAD transaction case need aie-rt APIs that
    # only AMD's internal build exposes.
    sed -i '/ops\/pm_load\/pm_load.cpp/d' src/CMakeLists.txt
    rm -rf src/ops/pm_load
    sed -i '/case (XAIE_IO_LOAD_PM_START): {/,/^  }$/d' src/txn/txn_utils.cpp

    # Protobuf 32 renamed this JSON print option.
    substituteInPlace src/fusion_rt/metastate_api.cpp \
      --replace-fail 'always_print_primitive_fields' 'always_print_fields_with_no_presence'

    # GCC 15 no longer pulls in <cstdint> transitively.
    for f in $(find . -name "*.cpp" -o -name "*.hpp" -o -name "*.h"); do
      if grep -q 'uint64_t\|int64_t\|uint32_t\|int32_t' "$f" 2>/dev/null; then
        if ! grep -q '#include <cstdint>' "$f" 2>/dev/null; then
          sed -i '1i #include <cstdint>' "$f"
        fi
      fi
    done
  '';

  passthru = {
    category = "AMD NPU";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Dynamic operator dispatch for AMD Ryzen AI";
    homepage = "https://github.com/amd/DynamicDispatch";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
    # Builds xrt (slow): CI evaluates it but does not build it.
    hydraPlatforms = [ ];
  };
}
