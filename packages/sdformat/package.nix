# SDFormat, the Simulation Description Format parser (Jetty, sdformat 16),
# with its Python bindings.
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
  python3Packages,
  ruby,
  tinyxml-2,
  urdfdom,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "sdformat";
  version = "16.1.0";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "sdformat";
    tag = "sdformat${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-iZ1it91NCJ8xUohp4WyoDfSEYGfp4MWT2DrtYCwjgjs=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    python3Packages.python
    python3Packages.pybind11
    ruby
  ];
  # The installed CMake config finds these again for every consumer.
  # cli11 and spdlog are for gz-utils, whose config looks for them but
  # which nixpkgs builds without propagating them.
  propagatedBuildInputs = [
    cli11
    gz-cmake
    gz-math
    gz-utils
    spdlog
    tinyxml-2
    urdfdom
  ];

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
    python3Packages.pytest
  ];

  # The bindings import gz.math, which gz-math installs outside
  # site-packages; upstream's test env only adds the build tree.
  preCheck = ''
    export PYTHONPATH=${gz-math}/lib/python''${PYTHONPATH:+:$PYTHONPATH}
  '';

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=sdformat16_([0-9.]+)$" ]; };
  };

  meta = {
    description = "Simulation Description Format (SDFormat) parser and description files";
    homepage = "https://github.com/gazebosim/sdformat";
    changelog = "https://github.com/gazebosim/sdformat/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
