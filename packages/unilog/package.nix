# Unified logging library at the bottom of the AMD Vitis AI stack (under xir,
# vart and the ONNX Runtime VitisAI execution provider). Adapted from
# robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639, pkgs/by-name/un/unilog.
# Upstream has no tags; the pin is the head of main.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  cmake,
  ninja,
  pkg-config,
  glog,
  # Boost 1.89 made boost_system header-only and dropped its CMake component,
  # which this and the rest of the Vitis stack still request. xrt pins the
  # same release, so the whole stack shares one Boost.
  boost188,
}:

stdenv.mkDerivation {
  pname = "unilog";
  version = "3.5.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "unilog";
    rev = "3abf8046d7ec8e651b8ec7ef19627a667ffaa741";
    hash = "sha256-TAsl/bCVwgVvbz3dQ9EKfBgZJArz4K2bae1hP/HuH3Q=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    glog
    boost188
  ];

  propagatedBuildInputs = [
    glog
    boost188
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_PYTHON" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  postPatch = ''
        substituteInPlace cmake/VitisCommon.cmake \
          --replace-fail "-Werror" ""

        # Fail instead of falling back to pkg-config when glog's CMake config
        # is missing: the fallback target lacks the include dirs consumers need.
        substituteInPlace cmake/config.cmake.in \
          --replace-fail 'if(NOT glog_FOUND)
      message(STATUS "cannot find glogConfig.cmake fallback to pkg-config")
      find_package(PkgConfig)
      pkg_search_module(PKG_GLOG REQUIRED IMPORTED_TARGET GLOBAL libglog)
      add_library(glog::glog ALIAS PkgConfig::PKG_GLOG)
    endif(NOT glog_FOUND)' 'if(NOT glog_FOUND)
      message(FATAL_ERROR "glog not found - ensure glog cmake config is available")
    endif(NOT glog_FOUND)'

        # Newer glog no longer exposes LogMessageVoidify.
        substituteInPlace include/UniLog/UniLog.hpp \
          --replace-fail '#include <glog/logging.h>' '#include <glog/logging.h>

    #ifndef GOOGLE_GLOG_LOGMESSAGEVOIDIFY_DEFINED
    namespace google {
    class LogMessageVoidify {
     public:
      void operator&(std::ostream&) {}
    };
    }
    #define GOOGLE_GLOG_LOGMESSAGEVOIDIFY_DEFINED
    #endif'
  '';

  passthru = {
    category = "AMD NPU";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Unified logging library for AMD Vitis AI";
    homepage = "https://github.com/amd/unilog";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
}
