# Langfuse from source: Next.js web, worker, and a migrate wrapper. Run by
# the services.langfuse NixOS module. nix-update bumps
# version/src/pnpmDeps/cargoDeps; the patched clickhouse crate is bumped by
# hand (postPatch fails loudly when upstream moves it or the pnpm major).
{
  lib,
  stdenv,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
  fetchPnpmDeps,
  pnpmConfigHook,
  pnpm_12,
  nodejs_24,
  rustPlatform,
  prisma-engines_6,
  prisma_6,
  go-migrate,
  bash,
  coreutils,
  openssl,
  makeWrapper,
  nix-update-script,
}:

let
  version = "4.56.0";

  src = fetchFromGitHub {
    owner = "langfuse";
    repo = "langfuse";
    tag = "v${version}";
    hash = "sha256-nSnGy2NjjIijsd2tXe+dMjnxx1cvbPfhKPB+kJVtuII=";
  };

  pnpm = pnpm_12;
  nodejs = nodejs_24;

  prismaEngine = "${lib.getLib prisma-engines_6}/lib/libquery_engine.node";

  migrate = go-migrate.overrideAttrs { tags = [ "clickhouse" ]; };

  clickhouseCrate = rec {
    version = "0.15.2";
    src = fetchurl {
      name = "clickhouse-${version}.tar.gz";
      url = "https://crates.io/api/v1/crates/clickhouse/${version}/download";
      hash = "sha256-dlQVT95Nl+wTIb/kw5ZVcL5vzQngkdqK/DFmq17ie+I=";
    };
  };

  # napi-rs names the addon after the platform; index.js loads it by that name.
  napiPlatform =
    {
      x86_64-linux = "linux-x64-gnu";
      aarch64-linux = "linux-arm64-gnu";
    }
    .${stdenv.hostPlatform.system};

  # @langfuse/native, the worker's Rust napi addon. `napi build` is a plain
  # cargo build plus a rename here: index.js/index.d.ts are committed.
  native = rustPlatform.buildRustPackage {
    pname = "langfuse-native";
    inherit version src;
    sourceRoot = "${src.name}/packages/native";

    cargoHash = "sha256-tgWXc1V7wi0P7reGhlotZHosU6PkVCGtuRJra1w6qj8=";

    postPatch = ''
      if ! grep -qx 'crate_version=${clickhouseCrate.version}' scripts/prepare-clickhouse-rs.sh; then
        echo "prepare-clickhouse-rs.sh no longer pins clickhouse ${clickhouseCrate.version}; update clickhouseCrate" >&2
        exit 1
      fi

      # What prepare-clickhouse-rs.sh does, minus the download: Cargo.lock
      # expects the patched crate as a path dependency, so the vendor dir
      # lacks it.
      crate=$NIX_BUILD_TOP/clickhouse-${clickhouseCrate.version}
      tar -xzf ${clickhouseCrate.src} -C $NIX_BUILD_TOP
      patch --directory="$crate" --strip=1 \
        < patches/clickhouse-${clickhouseCrate.version}-native-encoder.patch
      mkdir -p .cargo
      cat >> .cargo/config.toml <<EOF
      [patch.crates-io]
      clickhouse = { path = "$crate" }
      EOF
    '';

    # As upstream's rust:test script.
    checkFeatures = [ "napi/dyn-symbols" ];

    # The cargo hook overrides the profile's strip = "symbols"; stdenv's
    # default only drops debug info.
    stripAllList = [ "lib" ];

    installPhase = ''
      runHook preInstall
      install -Dm755 target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/liblangfuse_native.so \
        $out/lib/langfuse-native.${napiPlatform}.node
      runHook postInstall
    '';
  };

  # Postgres and ClickHouse migration assets for langfuse-migrate, with the
  # ClickHouse templates rendered as in the upstream web Dockerfile.
  migrations = stdenvNoCC.mkDerivation {
    pname = "langfuse-migrations";
    inherit version src;
    sourceRoot = "${src.name}/packages/shared";

    nativeBuildInputs = [ nodejs ];

    buildPhase = ''
      runHook preBuild
      node clickhouse/scripts/prepare-migrations.mjs materialize clickhouse/migrations
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r prisma clickhouse $out/
      cp scripts/cleanup.sql $out/cleanup.sql
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "langfuse";
  inherit version src;

  pnpmWorkspaces = [
    "web..."
    "worker..."
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      pnpmWorkspaces
      ;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-7Dam4quQqJFUtCBjivjLUgvWl6Lc+e4EyKxB5jh4zRg=";
  };

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    # setup hook exports PRISMA_*_ENGINE so `prisma generate` never downloads
    prisma-engines_6
    makeWrapper
  ];

  env = {
    NEXT_TELEMETRY_DISABLED = "1";
    NEXT_MANUAL_SIG_HANDLE = "true";
    # Skips env validation at build time, as in the upstream Dockerfile.
    DOCKER_BUILD = "1";
    CI = "true";
    SENTRYCLI_SKIP_DOWNLOAD = "1";
    PRISMA_ENGINES_CHECKSUM_IGNORE_MISSING = "1";
    pnpm_config_verify_deps_before_run = "false";
  };

  postPatch = ''
    pinned=$(node -p 'require("./package.json").engines.pnpm')
    # Same major, not older: older minors reject newer pnpm-workspace settings.
    oldest=$(printf '%s\n' "$pinned" "${pnpm.version}" | sort -V | head -n1)
    if [ "''${pinned%%.*}" != "${pnpm.majorVersion}" ] || [ "$oldest" != "$pinned" ]; then
      echo "upstream pins pnpm $pinned, this package builds with pnpm ${pnpm.version}" >&2
      exit 1
    fi

    cp ${native}/lib/*.node packages/native/

    # Not needed self-hosted (upstream Dockerfile deletes it too).
    rm -f web/src/middleware.ts
  '';

  buildPhase = ''
    runHook preBuild

    pnpm --filter=@langfuse/shared run db:generate
    pnpm --filter=@langfuse/shared run build

    NODE_OPTIONS=--max-old-space-size=8192 pnpm --filter=web run build
    pnpm --filter=worker run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    share=$out/share/langfuse
    mkdir -p $share $out/bin

    # web: Next.js standalone server plus its static assets, as the Dockerfile
    # lays them out under /app.
    cp -r web/.next/standalone $share/web
    mkdir -p $share/web/web/.next
    cp -r web/.next/static $share/web/web/.next/static
    cp -r web/public $share/web/web/public

    # worker: production deps only, workspace packages materialised.
    pnpm --filter=worker deploy --offline --prod --ignore-scripts $share/worker
    # The deployed @prisma/client is the bare package; give every copy the
    # .prisma/client runtime generated during the build (upstream's worker
    # Dockerfile does the same). Only one of the @prisma/client variants in
    # the store (they differ by typescript peer) holds it.
    generated=$(find node_modules/.pnpm -path '*/node_modules/.prisma/client' -type d | head -n 1)
    [ -n "$generated" ] || { echo "no generated .prisma/client found" >&2; exit 1; }
    find $share/worker/node_modules/.pnpm -path '*/node_modules/@prisma/client' -type d \
      | while read -r client; do
          dest=$(dirname "$(dirname "$client")")/.prisma
          rm -rf "$dest"
          mkdir -p "$dest"
          cp -r "$generated" "$dest/client"
        done

    # Next's output tracing copies only the packages it saw used, and the
    # optional cpu-features build fails offline, so pnpm's hoisting symlinks
    # to them dangle.
    find $share -xtype l -delete

    makeWrapper ${lib.getExe nodejs} $out/bin/langfuse-web \
      --chdir $share/web \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY ${prismaEngine} \
      --set NEXT_TELEMETRY_DISABLED 1 \
      --set NEXT_MANUAL_SIG_HANDLE true \
      --prefix PATH : ${lib.makeBinPath [ openssl ]} \
      --set-default PORT 3000 \
      --add-flags "$share/web/web/server.js --keepAliveTimeout 110000"

    makeWrapper ${lib.getExe nodejs} $out/bin/langfuse-worker \
      --chdir $share/worker \
      --set NODE_ENV production \
      --set PRISMA_QUERY_ENGINE_LIBRARY ${prismaEngine} \
      --prefix PATH : ${lib.makeBinPath [ openssl ]} \
      --set-default PORT 3030 \
      --add-flags "$share/worker/dist/index.js"

    install -Dm755 ${./migrate.sh} $share/migrate.sh
    patchShebangs $share/migrate.sh
    makeWrapper $share/migrate.sh $out/bin/langfuse-migrate \
      --set LANGFUSE_MIGRATIONS ${migrations} \
      --prefix PATH : ${
        # systemd units have no `sh`; up.sh also needs coreutils.
        lib.makeBinPath [
          prisma_6
          migrate
          nodejs
          bash
          coreutils
          # prisma probes the libssl version through the openssl binary.
          openssl
        ]
      }

    runHook postInstall
  '';

  passthru = {
    category = "Observability";
    inherit native migrations;
    # For nix-update, which looks the vendor hash up on the main package.
    inherit (native) cargoDeps;
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^v([0-9.]+)$"
      ];
    };
  };

  meta = {
    description = "Open source LLM engineering platform: observability, evals, prompt management";
    homepage = "https://langfuse.com";
    changelog = "https://github.com/langfuse/langfuse/releases/tag/v${finalAttrs.version}";
    # Core is MIT; the ee/ directory is under the Langfuse enterprise license
    # and stays inactive without a license key.
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "langfuse-web";
    platforms = lib.platforms.linux;
  };
})
