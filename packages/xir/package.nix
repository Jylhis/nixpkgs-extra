# Xilinx Intermediate Representation, the graph format of the AMD Vitis AI
# stack. Adapted from robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639,
# pkgs/by-name/xi/xir. Upstream has no tags; the pin is the head of main.
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
  boost188,
  unilog,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "xir";
  version = "3.5.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "xir";
    rev = "402341dd389d2f3ecd128e0a414d3fae3ca42db0";
    hash = "sha256-r6ZfIsUnUwVy31tb0JYWa24rxfnVl8W4AZbxqqVfc5s=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    protobuf
  ];

  buildInputs = [ abseil-cpp ];

  # xir-config.cmake runs find_package(unilog), and (unless the consumer
  # sets BUILD_SHARED_LIBS) find_package(Boost COMPONENTS graph) and
  # find_package(Protobuf).
  propagatedBuildInputs = [
    unilog
    protobuf
    boost188
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_PYTHON" false)
    (lib.cmakeBool "BUILD_DOC" false)
    (lib.cmakeBool "BUILD_CONTRIB" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  postPatch = ''
    substituteInPlace cmake/VitisCommon.cmake \
      --replace-fail "-Werror" ""

    # The build derives its version from git metadata.
    git init
    git config user.email "nix@build"
    git config user.name "Nix Build"
    git add -A
    git commit -m "Nix build" --allow-empty

    # GCC 15 no longer pulls in <cstdint> transitively.
    for f in $(find . -name "*.cpp" -o -name "*.hpp"); do
      if grep -q 'uint64_t\|int64_t\|uint32_t\|int32_t' "$f" 2>/dev/null; then
        if ! grep -q '#include <cstdint>' "$f" 2>/dev/null; then
          sed -i '1i #include <cstdint>' "$f"
        fi
      fi
    done

    # Protobuf-generated code calls abseil (including its logging internals)
    # directly, and newer protobuf no longer links those for its consumers.
    sed -i '/find_package(Protobuf REQUIRED)/a find_package(absl REQUIRED)' CMakeLists.txt
    sed -i 's/PRIVATE protobuf::libprotobuf/PRIVATE protobuf::libprotobuf absl::hash absl::raw_hash_set absl::strings absl::log_internal_message absl::log_internal_check_op/' src/xir/CMakeLists.txt
    sed -i 's/target_link_libraries(xir_util xir protobuf::libprotobuf unilog::unilog)/target_link_libraries(xir_util xir protobuf::libprotobuf unilog::unilog absl::hash absl::raw_hash_set absl::strings absl::log_internal_message absl::log_internal_check_op)/' tools/CMakeLists.txt
  '';

  passthru = {
    category = "AMD NPU";
    # A consumer that only lists xir must configure and link: the exported
    # CMake config calls find_package on its dependencies.
    tests.cmake-config =
      runCommandCC "xir-cmake-config"
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
          find_package(xir REQUIRED)
          add_executable(consumer main.cpp)
          target_link_libraries(consumer xir::xir)
          EOF
          echo 'int main() { return 0; }' > main.cpp
          cmake -G Ninja -B build -S .
          cmake --build build
          touch $out
        '';
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Xilinx Intermediate Representation for deep learning algorithms";
    homepage = "https://github.com/amd/xir";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "xir";
    platforms = [ "x86_64-linux" ];
  };
})
