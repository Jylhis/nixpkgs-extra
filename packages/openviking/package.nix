{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  nix-update-script,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openviking";
  version = "0.5.2.1";

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    tag = "v${finalAttrs.version}";
    hash = "sha256-v84jdUJuJvc435VeP2IuyvuQXCMWh2fFwFwkroPJXEk=";
  };

  cargoHash = "sha256-I9RMJQOeJKC9PMaKKhBCsTOZIr1vV6pcLjB6XxFUzFE=";

  # The repo is a Cargo workspace (crates/ov_cli, crates/ragfs,
  # crates/ragfs-python). Build and test only the CLI crate so we never
  # touch the pyo3 `ragfs-python` member.
  buildAndTestSubdir = "crates/ov_cli";

  # crates/ov_cli/build.rs reads OPENVIKING_VERSION to stamp `ov --version`;
  # without it the binary reports the placeholder 0.0.0.
  env.OPENVIKING_VERSION = finalAttrs.version;

  # reqwest is built with rustls-tls (aws-lc-rs backend), which needs cmake
  # at build time. No OpenSSL.
  nativeBuildInputs = [ cmake ];

  # The crate's tests expect a running OpenViking server / network access.
  doCheck = false;

  # The version-regex takes the newest `vX.Y.Z(.W)` and excludes the upstream
  # `…dev` pre-release tags.
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--version-regex"
      "^v([0-9.]+)$"
    ];
  };

  passthru.category = "AI tools";

  meta = {
    description = "Command-line client for OpenViking, a context filesystem for AI agents";
    homepage = "https://openviking.ai";
    changelog = "https://github.com/volcengine/OpenViking/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "ov";
    maintainers = with lib.maintainers; [ jylhis ];
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    platforms = lib.platforms.unix;
  };
})
