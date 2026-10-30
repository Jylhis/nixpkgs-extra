# Trace logging library for the AMD Vitis AI stack. Adapted from
# robcohen/nixpkgs branch vitis-ai (MIT), rev 9233c639,
# pkgs/by-name/tr/trace-logging. Upstream has no tags; the pin is the head of
# main.
{
  lib,
  stdenv,
  fetchFromGitHub,
  nix-update-script,
  cmake,
  ninja,
}:

stdenv.mkDerivation {
  pname = "trace-logging";
  version = "1.0.0-unstable-2024-11-05";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "trace_logging";
    rev = "8f3785a9aa0241d7dc5e8300bae5ce5cbc171dbe";
    hash = "sha256-KgD3o0dEwKkZG/EsKjO9imY8fDu9eX383DTqGtW+cN0=";
  };

  nativeBuildInputs = [
    cmake
    ninja
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_TEST" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
  ];

  passthru = {
    category = "AMD NPU";
    library = true;
    updateScript = nix-update-script { extraArgs = [ "--version=branch" ]; };
  };

  meta = {
    description = "Trace logging library for AMD Vitis AI";
    homepage = "https://github.com/amd/trace_logging";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
  };
}
