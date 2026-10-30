# workerd: Cloudflare's Workers runtime, repackaged from the prebuilt npm
# platform binaries (the ones wrangler ships). A source build needs bazel and
# most of Chromium's toolchain (nixpkgs#355460).
#
# UPDATE: keep `version` in lockstep with the workerd nixpkgs' wrangler expects
# (registry.npmjs.org/wrangler/<ver> -> `dependencies.workerd`), then refresh
# all four platform hashes; nix-update only does the current platform, hence
# `--version=skip`.
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  nix-update-script,
}:
let
  version = "1.20261012.1"; # = nixpkgs wrangler 4.151.1's pinned workerd
  plat =
    {
      x86_64-linux = {
        pkg = "workerd-linux-64";
        hash = "sha256-TPHmHNpIQyF7pWfL2QZ6NjPjhJ/1jDx8PB8hApSpTSM=";
      };
      aarch64-linux = {
        pkg = "workerd-linux-arm64";
        hash = "sha256-4uEP+5VrrGa4EAiPpDmCRiSv2sPrjeanpE5De49nzpk=";
      };
      x86_64-darwin = {
        pkg = "workerd-darwin-64";
        hash = "sha256-mbfLKCzeYEcuSr8NwoQfI3IiTlnW2OtvzloOBDpJYq4=";
      };
      aarch64-darwin = {
        pkg = "workerd-darwin-arm64";
        hash = "sha256-ldk2H+zo0glN5oe0L2xy+KDzNkfO9nwqvTTkTawODr4=";
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "workerd: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "workerd";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@cloudflare/${plat.pkg}/-/${plat.pkg}-${version}.tgz";
    inherit (plat) hash;
  };

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

  # ~100 MB release binary; stripping is slow and upstream already ships lean.
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/workerd $out/bin/workerd
    runHook postInstall
  '';

  # `workerd --version` prints the release date, e.g. "workerd 2026-10-12"
  # for npm version 1.20261012.1; check against the date derived from it.
  doInstallCheck = true;
  installCheckPhase =
    let
      d = builtins.elemAt (lib.splitVersion version) 1;
      date = "${lib.substring 0 4 d}-${lib.substring 4 2 d}-${lib.substring 6 2 d}";
    in
    ''
      $out/bin/workerd --version | grep -F "workerd ${date}"
    '';

  passthru = {
    category = "Developer tools";
    updateScript = nix-update-script {
      extraArgs = [ "--version=skip" ];
    };
  };

  meta = {
    description = "Cloudflare Workers JavaScript/Wasm runtime";
    homepage = "https://github.com/cloudflare/workerd";
    changelog = "https://github.com/cloudflare/workerd/releases";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "workerd";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
  };
}
