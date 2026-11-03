# Gazebo's common utilities (Jetty, gz-common 7): events, geospatial,
# graphics (mesh loading through assimp), audio/video through FFmpeg.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  ctestCheckHook,
  gtest,
  assimp,
  ffmpeg,
  gdal,
  gz-cmake,
  gz-math,
  gz-utils,
  cli11,
  spdlog,
  libuuid,
  tinyxml-2,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gz-common";
  version = "7.4.0";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-common";
    tag = "gz-common${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-XxAAva64aZWPk12H9dXioW/PmM42w5PSD8MnvM2dl5s=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  # The installed CMake config finds these again for every consumer.
  # cli11 and spdlog are for gz-utils, whose config looks for them but
  # which nixpkgs builds without propagating them.
  propagatedBuildInputs = [
    assimp
    cli11
    ffmpeg
    gdal
    gz-cmake
    gz-math
    gz-utils
    libuuid
    spdlog
    tinyxml-2
  ];

  cmakeFlags = [ (lib.cmakeBool "USE_EXTERNAL_TINYXML2" true) ];

  doCheck = true;
  checkInputs = [ gtest ];
  nativeCheckInputs = [ ctestCheckHook ];

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-common7_([0-9.]+)$" ]; };
  };

  meta = {
    description = "Common libraries for Gazebo robot simulation";
    homepage = "https://github.com/gazebosim/gz-common";
    changelog = "https://github.com/gazebosim/gz-common/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
