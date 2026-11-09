{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
  nix-update-script,
  versionCheckHook,
  writableTmpDirAsHomeHook,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "openviking";
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "volcengine";
    repo = "OpenViking";
    tag = "v${finalAttrs.version}";
    hash = "sha256-pRJgtXRDl9nq6l9Riy6LIFtUkExIPo1CXqTaeNyYAAc=";
  };

  cargoHash = "sha256-Cw/TXG8NP3jdEXz5H2at+GyBAe8AckyypmIncPNpnSc=";

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

  nativeInstallCheckInputs = [
    versionCheckHook
    writableTmpDirAsHomeHook
  ];
  # With a HOME but no config, every ov command, --version included, asks
  # for a display language first; pick one in the temporary HOME.
  versionCheckKeepEnvironment = [ "HOME" ];
  preVersionCheck = ''
    $out/bin/ov language en
  '';
  doInstallCheck = true;

  passthru = {
    category = "Memory & Code Intelligence";
    upstream = [ "llm-agents" ];
    # The version-regex takes the newest `vX.Y.Z(.W)` and excludes the
    # upstream `…dev` pre-release tags.
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^v([0-9.]+)$"
      ];
    };
  };

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
