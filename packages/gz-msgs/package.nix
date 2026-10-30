# Gazebo's protobuf message definitions and generated C++/Python bindings
# (Jetty, gz-msgs 12).
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  ctestCheckHook,
  gtest,
  gz-cmake,
  gz-math,
  gz-utils,
  cli11,
  spdlog,
  zlib,
  protobuf,
  python3,
  python3Packages,
  tinyxml-2,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gz-msgs";
  version = "12.0.2";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-msgs";
    tag = "gz-msgs${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-yKuD08jZtQmtCWO/TvLngqhRVAbu4bZC9B4e9KxKr4M=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    protobuf
    python3
  ];
  # The installed CMake config finds these again for every consumer.
  # cli11 and spdlog are for gz-utils, whose config looks for them but
  # which nixpkgs builds without propagating them.
  propagatedBuildInputs = [
    cli11
    gz-cmake
    gz-math
    gz-utils
    protobuf
    spdlog
    tinyxml-2
    zlib
  ];
  # The config also finds Python, which runs the message generator.
  propagatedNativeBuildInputs = [ python3 ];

  # Upstream's relative runtime paths (`../../../${CMAKE_INSTALL_LIBEXECDIR}`)
  # double up with the absolute dirs the cmake hook passes; single output, so
  # relative dirs install to the same place.
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBEXECDIR" "libexec")
  ];

  doCheck = true;
  checkInputs = [ gtest ];
  nativeCheckInputs = [
    ctestCheckHook
    # python/test imports the generated bindings, which need protobuf.
    python3Packages.protobuf
  ];

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-msgs12_(.*)" ]; };
  };

  meta = {
    description = "Protobuf messages for Gazebo robot simulation";
    homepage = "https://github.com/gazebosim/gz-msgs";
    changelog = "https://github.com/gazebosim/gz-msgs/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
