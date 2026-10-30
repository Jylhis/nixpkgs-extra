# mem0, the long-term memory library for AI agents, built from the upstream
# source. Takes the caller's python package set so any interpreter can add it:
# `python3.withPackages (ps: [ (callPackage ../mem0ai { python3Packages = ps; }) ])`.
#
# Dependencies cover the self-hosted path (pgvector, OpenAI-compatible
# LLM/embedder, SQLite history); other stores and providers are imported lazily.
{
  lib,
  python3Packages,
  fetchFromGitHub,
  nix-update-script,
}:

let
  # nixpkgs marks posthog broken because its test suite fails against mcp 2.
  # mcp is a test-only input there, so the library is fine without the tests.
  posthog = python3Packages.posthog.overridePythonAttrs (old: {
    doCheck = false;
    meta = old.meta // {
      broken = false;
    };
  });
in
python3Packages.buildPythonPackage (finalAttrs: {
  pname = "mem0ai";
  version = "2.2.1";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "mem0ai";
    repo = "mem0";
    tag = "v${finalAttrs.version}";
    hash = "sha256-C7E7Xd1+7Vy0ZwRIjblihexQTkS2YBPx5Sogz6ACYXs=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = [
    posthog
  ]
  ++ (with python3Packages; [
    httpx
    openai
    protobuf
    psycopg
    psycopg-pool
    pydantic
    pytz
    qdrant-client
    sqlalchemy
  ]);

  # Upstream caps protobuf below 7; mem0 only reaches it through
  # qdrant-client and posthog.
  pythonRelaxDeps = [ "protobuf" ];

  # mem0.memory.setup creates ~/.mem0 at import time; the build has no HOME.
  env.MEM0_DIR = "/tmp/mem0";

  pythonImportsCheck = [
    "mem0"
    "mem0.vector_stores.pgvector"
  ];

  # The test suite needs network access and live provider credentials.
  doCheck = false;

  passthru = {
    category = "AI tools";
    library = true;
    # The monorepo also tags its SDKs and plugins (ts-v*, cli-v*, ...).
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^v([0-9.]+)$"
      ];
    };
  };

  meta = {
    description = "Long-term memory layer for AI agents";
    homepage = "https://github.com/mem0ai/mem0";
    changelog = "https://github.com/mem0ai/mem0/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.all;
  };
})
