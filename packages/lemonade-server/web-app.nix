# Adapted from noamsto/nix-amd-ai (MIT), rev 4536648, pkgs/lemonade/web-app.nix.
{
  lib,
  buildNpmPackage,
  nodejs,
  version,
  src,
}:
buildNpmPackage {
  pname = "lemonade-web-app";
  inherit version src nodejs;

  sourceRoot = "${src.name}/src/web-app";

  # Upstream ships no lockfile; this one comes from
  # `npm install --package-lock-only`. Refresh on dep bumps.
  postPatch = ''
    cp ${./web-app-package-lock.json} ./package-lock.json
  '';

  npmDepsHash = "sha256-Ovloy6fA9UEQ6SzVgiFeFt1ysgakt9bN2ZgJkEwtSFI=";

  # webpack.config.js resolves ../app/src/renderer/index.tsx, so the sibling
  # src/app/ must exist; fail loudly if upstream rearranges that.
  preBuild = ''
    if [ ! -d ../app/src/renderer ]; then
      echo "expected ../app/src/renderer next to src/web-app, got:" >&2
      ls .. >&2
      exit 1
    fi
  '';

  npmBuildScript = "build";

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r dist/renderer/. $out/
    runHook postInstall
  '';

  dontNpmInstall = true;

  meta = {
    description = "Lemonade web UI (React) — static bundle for serving by lemond";
    homepage = "https://github.com/lemonade-sdk/lemonade";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
  };
}
