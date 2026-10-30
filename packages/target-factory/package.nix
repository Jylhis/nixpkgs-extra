# Generates the DPU target descriptions the AMD Vitis AI runtime (vart)
# loads. Adapted from robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639,
# pkgs/by-name/ta/target-factory. Upstream has no tags; the pin is the head
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
  protobuf,
  abseil-cpp,
  unilog,
  xir,
}:

stdenv.mkDerivation {
  pname = "target-factory";
  version = "3.5.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "target_factory";
    rev = "7270acd2eb90e8f5b4fc7354c66c2a3fd960111f";
    hash = "sha256-GF8x4a0+5zGRlu6wrMN8YYSvl1iybNvCFjLYmb1jm3M=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
    protobuf
  ];

  buildInputs = [
    protobuf
    abseil-cpp
    unilog
    xir
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_PYTHON" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
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

    # GCC 15 no longer pulls in <cstdint> transitively.
    for f in $(find . -name "*.cpp" -o -name "*.hpp"); do
      if grep -q 'uint64_t\|int64_t\|uint32_t\|int32_t' "$f" 2>/dev/null; then
        if ! grep -q '#include <cstdint>' "$f" 2>/dev/null; then
          sed -i '1i #include <cstdint>' "$f"
        fi
      fi
    done

    sed -i '/find_package(Protobuf REQUIRED)/a find_package(absl REQUIRED)' CMakeLists.txt
  '';

  passthru = {
    category = "AMD NPU";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Factory to generate DPU target descriptions for AMD Vitis AI";
    homepage = "https://github.com/amd/target_factory";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
}
