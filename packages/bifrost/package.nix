# Bifrost LLM gateway (Go + embedded Next.js UI); built from the tagged
# source with upstream's own UI expression. Binary: bifrost-http.
{
  lib,
  buildNpmPackage,
  buildGo127Module,
  fetchFromGitHub,
  pkg-config,
  sqlite,
  nix-update-script,
}:

let
  version = "2.3.2";

  src = fetchFromGitHub {
    owner = "maximhq";
    repo = "bifrost";
    tag = "transports/v${version}";
    hash = "sha256-qkAn7D/fZkCumpwjD11gSF5MSUKZqQ2/HojYxJJJcCg=";
  };

  # Static Next.js export, embedded into the Go binary. Mirrors upstream's
  # nix/packages/bifrost-ui.nix (importing it from src would be IFD).
  bifrost-ui = buildNpmPackage {
    pname = "bifrost-ui";
    inherit version src;
    sourceRoot = "source/ui";
    npmDepsHash = "sha256-sH7vaaCBRLSwDUNj/C1mwQtaQ+1Ft8AJkILHnugkceQ=";

    # next/font/google needs network at build time; drop it from the layout.
    postPatch = ''
      cat > app/layout.tsx <<'EOT'
      import "./globals.css"

      export default function RootLayout({ children }: { children: React.ReactNode }) {
        return (
          <html lang="en" suppressHydrationWarning>
            <body className="font-sans antialiased">{children}</body>
          </html>
        )
      }
      EOT
    '';

    npmBuildScript = "build-enterprise";
    env.NEXT_TELEMETRY_DISABLED = "1";
    env.NEXT_DISABLE_ESLINT = "1";

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/ui"
      cp -R --no-preserve=mode,ownership,timestamps out/. "$out/ui/"
      runHook postInstall
    '';
  };

  # transports/go.mod requires the sibling modules by version; build them from
  # the same checkout. Upstream tags go 1.27.3 but nixpkgs ships 1.27.1, so
  # relax the directive in every module (no 1.27.2+ language feature is used).
  localModules = ''
    sed -i 's/^go 1\.27\.3$/go 1.27.1/' core/go.mod framework/go.mod plugins/*/go.mod transports/go.mod
    for m in core framework; do
      echo "replace github.com/maximhq/bifrost/$m => ../$m" >> transports/go.mod
    done
    for d in plugins/*/; do
      m=$(basename "$d")
      echo "replace github.com/maximhq/bifrost/plugins/$m => ../plugins/$m" >> transports/go.mod
    done
  '';
in
buildGo127Module {
  pname = "bifrost";
  inherit version src;

  modRoot = "transports";
  subPackages = [ "bifrost-http" ];
  vendorHash = "sha256-0OOMOiJyFwf5tbS7uhfsIjlcLHZh/ob3xyRSudMTSIg=";

  postPatch = localModules;
  overrideModAttrs = _: {
    postPatch = localModules;
  };

  env.CGO_ENABLED = "1";
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ sqlite ];

  # //go:embed all:ui needs the exported UI inside the package directory.
  preBuild = ''
    rm -rf bifrost-http/ui
    mkdir -p bifrost-http/ui
    cp -R --no-preserve=mode,ownership,timestamps ${bifrost-ui}/ui/. bifrost-http/ui/
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=v${version}"
  ];

  doCheck = false;

  passthru = {
    ui = bifrost-ui;
    category = "AI tools";
    # The release tags are prefixed with "transports/"; the UI's npmDepsHash
    # still needs a manual refresh after a bump.
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "transports/v(.*)"
      ];
    };
  };

  meta = {
    description = "Go LLM gateway with a web UI, governance and observability plugins";
    homepage = "https://github.com/maximhq/bifrost";
    changelog = "https://github.com/maximhq/bifrost/releases/tag/transports/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "bifrost-http";
    platforms = lib.platforms.linux;
  };
}
