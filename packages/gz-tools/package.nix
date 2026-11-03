# Gazebo's `gz` command-line front end (Jetty, gz-tools 2), which dispatches
# to the subcommands other Gazebo libraries install.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  gz-cmake,
  backward-cpp,
  ruby,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gz-tools";
  version = "2.0.4";

  src = fetchFromGitHub {
    owner = "gazebosim";
    repo = "gz-tools";
    tag = "gz-tools${lib.versions.major finalAttrs.version}_${finalAttrs.version}";
    hash = "sha256-WVeZg7Wreqz0eScbrgELEAsmpfr1Dy7HogZFjGEht/I=";
  };

  strictDeps = true;
  __structuredAttrs = true;

  nativeBuildInputs = [ cmake ];
  # bin/gz is a Ruby script: ruby in buildInputs patches its shebang.
  buildInputs = [
    gz-cmake
    backward-cpp
    ruby
  ];

  # Upstream builds runtime paths as `../../../${CMAKE_INSTALL_LIBEXECDIR}`
  # (from lib/ruby/gz) or `${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}`,
  # which double up with the absolute dirs the cmake hook passes. This is a
  # single-output package, so relative dirs install to the same place.
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_INSTALL_BINDIR" "bin")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBDIR" "lib")
    (lib.cmakeFeature "CMAKE_INSTALL_LIBEXECDIR" "libexec")
    (lib.cmakeBool "USE_SYSTEM_BACKWARDCPP" true)
  ];

  doCheck = true;
  nativeCheckInputs = [ ruby ];

  passthru = {
    category = "Robotics";
    updateScript = nix-update-script { extraArgs = [ "--version-regex=gz-tools2_([0-9.]+)$" ]; };
  };

  meta = {
    description = "Command-line front end for Gazebo libraries";
    homepage = "https://github.com/gazebosim/gz-tools";
    changelog = "https://github.com/gazebosim/gz-tools/blob/${finalAttrs.src.tag}/Changelog.md";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "gz";
    platforms = lib.platforms.linux;
  };
})
