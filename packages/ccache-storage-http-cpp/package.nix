{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  curl,
  libuv,
  python3,
  nix-update-script,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ccache-storage-http-cpp";
  version = "0.11";

  src = fetchFromGitHub {
    owner = "ccache";
    repo = "ccache-storage-http-cpp";
    tag = "v${finalAttrs.version}";
    hash = "sha256-4CZbTf0cxjLHi7GW2pAFYGm9NmbTAA0OM0IEmTn2Ffk=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    curl
    libuv
  ];

  # tests/integration drives the helper against a localhost HTTP server.
  doCheck = true;
  nativeCheckInputs = [ python3 ];
  postPatch = ''
    patchShebangs tests/integration/test_storage_helper
  '';

  passthru = {
    category = "Developer tools";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Remote storage helper for ccache using HTTP/HTTPS servers";
    homepage = "https://github.com/ccache/ccache-storage-http-cpp";
    changelog = "https://github.com/ccache/ccache-storage-http-cpp/blob/v${finalAttrs.version}/CHANGELOG.md";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "ccache-storage-http";
    platforms = lib.platforms.unix;
  };
})
