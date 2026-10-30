# NVIDIA NGC CLI (`ngc`), from NVIDIA's prebuilt PyInstaller bundle.
{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchzip,
  zlib,
}:

let
  sources = {
    x86_64-linux = {
      file = "ngccli_linux.zip";
      hash = "sha256-vXuocChWDpZBQ11PF7mZuONtR6pYlgTKiYGcE4h87S0=";
    };
    aarch64-linux = {
      file = "ngccli_arm64.zip";
      hash = "sha256-YEv3x5Gnp1TSpmk8TvYp8iHNrO5SIiFBZR3stFCf4r0=";
    };
  };
  source =
    sources.${stdenv.hostPlatform.system}
      or (throw "nvidia-cli: unsupported system ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nvidia-cli";
  version = "4.36.6";

  src = fetchzip {
    url = "https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli/versions/${finalAttrs.version}/files/${source.file}";
    inherit (source) hash;
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/libexec/nvidia-cli $out/bin
    cp -r ngc-cli/. $out/libexec/nvidia-cli
    # The zip does not keep the executable bit.
    chmod +x $out/libexec/nvidia-cli/ngc
    ln -s $out/libexec/nvidia-cli/ngc $out/bin/ngc

    runHook postInstall
  '';

  # No updateScript: NGC is not a source nix-update can track. The newest
  # version is `.recipe.latestVersionIdStr` of
  # https://api.ngc.nvidia.com/v2/resources/nvidia/ngc-apps/ngc_cli; bump the
  # version and both hashes together.
  passthru.category = "Developer tools";

  meta = {
    description = "NVIDIA NGC command-line interface";
    homepage = "https://org.ngc.nvidia.com/setup/installers/cli";
    changelog = "https://docs.ngc.nvidia.com/cli/release_notes.html";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "ngc";
    platforms = lib.attrNames sources;
  };
})
