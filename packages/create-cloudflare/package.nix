# create-cloudflare (C3): Cloudflare's project scaffolder. The npm tarball
# ships a bundled dist/cli.js plus the offline templates and no runtime
# dependencies, so this is fetchurl + a node wrapper rather than
# buildNpmPackage. Keep the tree intact: dist/cli.js resolves ../templates.
{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs,
  makeWrapper,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "create-cloudflare";
  version = "2.74.6";

  src = fetchurl {
    url = "https://registry.npmjs.org/create-cloudflare/-/create-cloudflare-${finalAttrs.version}.tgz";
    hash = "sha256-mvLIj87toi5MpAHf2tANi26oNgDxfCcFN2HUm8XrwL4=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/create-cloudflare
    cp -r . $out/lib/create-cloudflare/
    makeWrapper ${lib.getExe nodejs} $out/bin/create-cloudflare \
      --add-flags "$out/lib/create-cloudflare/bin/c3.js"
    ln -s $out/bin/create-cloudflare $out/bin/c3
    runHook postInstall
  '';

  passthru = {
    category = "Developer tools";
    updateScript = nix-update-script {
      extraArgs = [
        "--url=https://github.com/cloudflare/workers-sdk"
        "--version-regex=create-cloudflare@(.*)"
      ];
    };
  };

  meta = {
    description = "CLI for scaffolding Cloudflare Workers projects, also known as C3";
    homepage = "https://github.com/cloudflare/workers-sdk/tree/main/packages/create-cloudflare";
    changelog = "https://github.com/cloudflare/workers-sdk/blob/main/packages/create-cloudflare/CHANGELOG.md";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "create-cloudflare";
    platforms = lib.platforms.all;
  };
})
