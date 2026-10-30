# Client library and `gz fuel` commands for Gazebo Fuel model servers
# (Jetty, gz-fuel-tools 11).
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  ctestCheckHook,
  gtest,
  curl,
  gz-cmake,
  gz-common,
  gz-msgs,
  gz-tools,
  jsoncpp,
  libyaml,
  libzip,
  tinyxml-2,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gz-fuel-tools";
  version = "11.0.0";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-fuel-tools";
    tag = "gz-fuel-tools${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-IFnaXBURpN5xTCxFjlcZk9n0sCsUnPBr3NUZrf7Xde0=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [
    cmake
    pkg-config
    gz-tools
  ];
  # The installed CMake config finds these again for every consumer.
  propagatedBuildInputs = [
    curl
    gz-cmake
    gz-common
    gz-msgs
    jsoncpp
    libyaml
    libzip
    tinyxml-2
  ];

  # These download from fuel.gazebosim.org, which the sandbox can't reach.
  env.GTEST_FILTER =
    "-"
    + lib.concatStringsSep ":" [
      "CmdLine.*Download*"
      "CmdLine.*ListConfigServerUgly"
      "CollectionTest/*"
      "FuelClientTest.DownloadWorld"
      "FuelClientTest/FuelClientDownloadTest.*"
      "FuelClientTest.ModelDependencies"
      "FuelClientTest.Models"
      "FuelClientTest.ModelsCheckCached"
      "FuelClientTest.Worlds"
      "InterfaceTest.FetchResources"
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
  nativeCheckInputs = [ ctestCheckHook ];
  # The `gz fuel` command config only points at the Ruby command file
  # once installed, so the CLI test runs in installCheckPhase.
  disabledTests = [ "UNIT_gz_TEST" ];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    GZ_CONFIG_PATH=$out/share/gz ctest --output-on-failure -R '^UNIT_gz_TEST$'
    runHook postInstallCheck
  '';

  passthru = {
    category = "Robotics";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-fuel-tools11_(.*)" ]; };
  };

  meta = {
    description = "Client library and command-line tools for Gazebo Fuel servers";
    homepage = "https://github.com/gazebosim/gz-fuel-tools";
    changelog = "https://github.com/gazebosim/gz-fuel-tools/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
  };
})
