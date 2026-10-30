# Graph execution engine for AMD Vitis AI on top of vart and XRT. Adapted
# from robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639,
# pkgs/by-name/gr/graph-engine. Upstream has no tags; the pin is the head of
# main.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  cmake,
  ninja,
  pkg-config,
  git,
  boost188,
  libuuid,
  unilog,
  xir,
  vart,
  xrt,
}:

stdenv.mkDerivation {
  pname = "graph-engine";
  version = "1.0.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "graph_engine";
    rev = "2410822ec0450ff3602ef26bbe074685765c9144";
    hash = "sha256-W9vtQ/wq6l0gT2B5w51NBK0AB6MG3dspZSzTqCzUMgU=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    git
  ];

  buildInputs = [
    boost188
    libuuid
    unilog
    xir
    vart
    xrt
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeFeature "XRT_DIR" "${xrt}/opt/xilinx/xrt/share/cmake/XRT")
    (lib.cmakeFeature "CMAKE_PREFIX_PATH" "${xrt}/opt/xilinx/xrt")
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

    # GCC 15 no longer pulls in <cstdint> transitively.
    for f in $(find . -name "*.cpp" -o -name "*.hpp"); do
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
    description = "Graph execution engine for AMD Vitis AI";
    homepage = "https://github.com/amd/graph_engine";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
}
