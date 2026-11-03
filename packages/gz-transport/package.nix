# Gazebo's publish/subscribe and service transport (Jetty, gz-transport 15),
# over ZeroMQ and Zenoh, with its Python bindings.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  ctestCheckHook,
  gtest,
  cppzmq,
  gz-cmake,
  gz-math,
  gz-msgs,
  gz-tools,
  libsodium,
  libuuid,
  python3Packages,
  sqlite,
  zenoh-c,
  zenoh-cpp,
  zeromq,
  nix-update-script,
}:

let
  pythonTests = [
    "options_TEST.py"
    "pubSub_TEST.py"
    "requester_TEST.py"
  ];
in
stdenv.mkDerivation (finalAttrs: {
  pname = "gz-transport";
  version = "15.1.0";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-transport";
    tag = "gz-transport${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-a+PbuwTZ9zFRAJmnrbqmEpbecoetPat6LiAITP4sV2E=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    python3Packages.python
    python3Packages.pybind11
  ];
  # libgz-transport links libsodium directly (through zeromq's link
  # flags), so it has to be an input to land in the library's RUNPATH.
  buildInputs = [
    libsodium
    sqlite
    zenoh-c
    zenoh-cpp
  ];
  # The installed CMake config finds these again for every consumer.
  propagatedBuildInputs = [
    cppzmq
    gz-cmake
    gz-msgs
    gz-tools
    libuuid
    zeromq
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
    python3Packages.protobuf
    python3Packages.pytest
  ];
  # The Python tests import gz.transport from the install prefix (its
  # package files are only assembled on install), so they run in
  # installCheckPhase instead.
  disabledTests = pythonTests;

  doInstallCheck = true;
  # gz.msgs (and gz.math through it) live outside site-packages.
  installCheckPhase = ''
    runHook preInstallCheck
    export PYTHONPATH=${gz-msgs}/lib/python:${gz-math}/lib/python''${PYTHONPATH:+:$PYTHONPATH}
    ctest --output-on-failure -R '${lib.concatMapStringsSep "|" (t: "^${t}$") pythonTests}'
    # The installed CLI resolves its executables and their libraries.
    GZ_CONFIG_PATH=$out/share/gz ${lib.getExe gz-tools} topic -l
    GZ_CONFIG_PATH=$out/share/gz ${lib.getExe gz-tools} service -l
    runHook postInstallCheck
  '';

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-transport15_([0-9.]+)$" ]; };
  };

  meta = {
    description = "Transport library for Gazebo component communication";
    homepage = "https://github.com/gazebosim/gz-transport";
    changelog = "https://github.com/gazebosim/gz-transport/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
