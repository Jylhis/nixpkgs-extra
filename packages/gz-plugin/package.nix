# Gazebo plugin loading library (Jetty, gz-plugin 4).
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ctestCheckHook,
  gtest,
  gz-cmake,
  gz-utils,
  cli11,
  spdlog,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gz-plugin";
  version = "4.0.0-pre1";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-plugin";
    tag = "gz-plugin${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-/T0Gav0b9BG39qm8v8J7qnpYdLSwsRZVar4i5zUyF5M=";
  };

  postPatch = ''
    patchShebangs test/static_assertions/testrunner.bash
  '';

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [ cmake ];
  # The installed CMake config finds these again for every consumer.
  # cli11 and spdlog are for gz-utils, whose config looks for them but
  # which nixpkgs builds without propagating them.
  propagatedBuildInputs = [
    cli11
    gz-cmake
    gz-utils
    spdlog
  ];

  # Upstream builds runtime paths as `../../../${CMAKE_INSTALL_LIBEXECDIR}`
  # (from lib/ruby/gz) or `${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}`,
  # which double up with the absolute dirs the cmake hook passes. This is a
  # single-output package, so relative dirs install to the same place.
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBEXECDIR" "libexec")
  ];

  doCheck = true;
  checkInputs = [ gtest ];
  nativeCheckInputs = [ ctestCheckHook ];

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-plugin4_(.*)" ]; };
  };

  meta = {
    description = "Cross-platform C++ library for dynamically loading Gazebo plugins";
    homepage = "https://github.com/gazebosim/gz-plugin";
    changelog = "https://github.com/gazebosim/gz-plugin/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
