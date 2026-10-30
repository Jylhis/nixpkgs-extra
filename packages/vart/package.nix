# Vitis AI Runtime: the runner API the ONNX Runtime VitisAI execution
# provider and graph-engine sit on. Adapted from robcohen/nixpkgs branch
# vitis-ai (MIT), rev 9233c639, pkgs/by-name/va/vart. Upstream has no tags;
# the pin is the head of main.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  runCommandCC,
  cmake,
  ninja,
  pkg-config,
  git,
  protobuf,
  abseil-cpp,
  glog,
  xir,
  target-factory,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "vart";
  version = "3.5.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "vart";
    rev = "dafd687831e817720f430e6f6033f5f2cd78fe5b";
    hash = "sha256-nzt9D9jC7V2DSWHYZbmxesCmZN2Gc3CFanzpM0T6lUI=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    protobuf
  ];

  buildInputs = [
    abseil-cpp
    target-factory
  ];

  # vart-config.cmake runs find_package(xir), and vart::util links
  # glog::glog.
  propagatedBuildInputs = [
    xir
    glog
  ];

  # The CPU, simulator, DPU and XRNN runners need AMD's closed board support;
  # this builds the runner API and its generic parts.
  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_PYTHON" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "ENABLE_CPU_RUNNER" false)
    (lib.cmakeBool "ENABLE_SIM_RUNNER" false)
    (lib.cmakeBool "ENABLE_DPU_RUNNER" false)
    (lib.cmakeBool "ENABLE_XRNN_RUNNER" false)
  ];

  postPatch = ''
    substituteInPlace cmake/VitisCommon.cmake \
      --replace-fail "-Werror" ""

    # abseil (through protobuf's headers) needs C++20.
    find . \( -name CMakeLists.txt -o -name "*.cmake" \) -exec \
      sed -i -E 's/(set ?\(CMAKE_CXX_STANDARD) 17\)/\1 20)/; s/CXX_STANDARD 17\)/CXX_STANDARD 20)/' {} +

    # The build derives its version from git metadata.
    git init
    git config user.email "nix@build"
    git config user.name "Nix Build"
    git add -A
    git commit -m "Nix build" --allow-empty

    # GCC 15 no longer pulls these headers in transitively.
    for f in $(find . -name "*.cpp" -o -name "*.hpp"); do
      if grep -q 'uint64_t\|int64_t\|uint32_t\|int32_t' "$f" 2>/dev/null; then
        if ! grep -q '#include <cstdint>' "$f" 2>/dev/null; then
          sed -i '1i #include <cstdint>' "$f"
        fi
      fi
      if grep -qE 'syscall|[^a-z]close\(' "$f" 2>/dev/null; then
        if ! grep -q '#include <unistd.h>' "$f" 2>/dev/null; then
          sed -i '1i #include <unistd.h>' "$f"
        fi
      fi
      if grep -q 'SYS_' "$f" 2>/dev/null; then
        if ! grep -q '#include <sys/syscall.h>' "$f" 2>/dev/null; then
          sed -i '1i #include <sys/syscall.h>' "$f"
        fi
      fi
    done

    sed -i '/find_package(Protobuf REQUIRED)/a find_package(absl REQUIRED)' CMakeLists.txt

    # Drop a link directory pointing into a conda prefix.
    sed -i '/link_directories.*CONDA_PREFIX/d' CMakeLists.txt
  '';

  passthru = {
    category = "AMD NPU";
    library = true;
    # A consumer that only lists vart must configure and link: the exported
    # CMake config calls find_package on its dependencies.
    tests.cmake-config =
      runCommandCC "vart-cmake-config"
        {
          nativeBuildInputs = [
            cmake
            ninja
          ];
          buildInputs = [ finalAttrs.finalPackage ];
        }
        ''
          cat > CMakeLists.txt <<'EOF'
          cmake_minimum_required(VERSION 3.16)
          project(consumer CXX)
          find_package(vart REQUIRED COMPONENTS util runner mem-manager)
          add_executable(consumer main.cpp)
          target_link_libraries(consumer vart::util vart::runner vart::mem-manager)
          EOF
          echo 'int main() { return 0; }' > main.cpp
          cmake -G Ninja -B build -S .
          cmake --build build
          touch $out
        '';
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Vitis AI Runtime for AMD accelerators";
    homepage = "https://github.com/amd/vart";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
})
