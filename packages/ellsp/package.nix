# ellsp: Language Server Protocol server for Emacs Lisp (github.com/elisp-lsp/Ellsp).
#
# Ellsp is an Emacs package that talks LSP over a small Node proxy
# (proxy/start.js). The wrapper starts the proxy, which spawns the Emacs
# built here with ellsp and its dependencies on the load path (ELLSP_EMACS).
# `emacs` selects the Emacs build; the default is nixpkgs' emacs.
#
# msgu is not in nixpkgs' emacsPackages and is pinned here.
{
  lib,
  fetchFromGitHub,
  buildNpmPackage,
  makeWrapper,
  nodejs,
  emacsPackagesFor,
  emacs,
  nix-update-script,
}:
buildNpmPackage (finalAttrs: {
  pname = "ellsp";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "elisp-lsp";
    repo = "Ellsp";
    tag = finalAttrs.version;
    hash = "sha256-JlM7PeQyloYORA4CJgz+cbChrxWjEE7NJgvsHIjIUIY=";
  };

  sourceRoot = "${finalAttrs.src.name}/proxy";

  npmDepsHash = "sha256-9aIlBRFFgBcXdWfHYarWNSYLV9LPsxytBUr8xPmEp1o=";

  dontNpmBuild = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/libexec/ellsp $out/bin
    cp start.js env.js util.js $out/libexec/ellsp/
    cp -r node_modules $out/libexec/ellsp/
    makeWrapper ${lib.getExe nodejs} $out/bin/ellsp \
      --add-flags $out/libexec/ellsp/start.js \
      --set ELLSP_EMACS ${finalAttrs.passthru.emacsWithEllsp}/bin/emacs
    runHook postInstall
  '';

  passthru =
    let
      epkgs = emacsPackagesFor emacs;

      msgu = epkgs.trivialBuild {
        pname = "msgu";
        version = "0.1.0";
        src = fetchFromGitHub {
          owner = "jcs-elpa";
          repo = "msgu";
          tag = "0.1.0";
          hash = "sha256-Jnse1nX+NtGbN39P/ug3PdB8/PdrMITFwACPHueOeZU=";
        };
      };

      ellspEl = epkgs.trivialBuild {
        pname = "ellsp";
        inherit (finalAttrs) version src;
        packageRequires = with epkgs; [
          lsp-mode
          company
          log4e
          dash
          s
          msgu
        ];
      };
    in
    {
      emacsWithEllsp = epkgs.withPackages (_: [ ellspEl ]);
      category = "Developer tools";
      updateScript = nix-update-script { };
    };

  meta = {
    description = "Language Server Protocol server for Emacs Lisp";
    homepage = "https://github.com/elisp-lsp/Ellsp";
    changelog = "https://github.com/elisp-lsp/Ellsp/releases/tag/${finalAttrs.version}";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "ellsp";
    platforms = lib.platforms.unix;
  };
})
