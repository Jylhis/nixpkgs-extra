# mem0 self-hosted REST server: the `server/` directory of mem0ai/mem0 at the
# tag matching the mem0ai library. Upstream ships only a Dockerfile, so the
# modules are installed under libexec with a launcher that runs the auth DB
# migrations and uvicorn. config-file.patch adds MEM0_CONFIG_FILE (a full
# MemoryConfig) in place of the hard-coded OpenAI defaults.
{
  lib,
  fetchFromGitHub,
  python3Packages,
  mem0ai,
  nix-update-script,
}:

python3Packages.buildPythonApplication (finalAttrs: {
  pname = "mem0-server";
  version = "2.2.1";
  format = "other";

  src = fetchFromGitHub {
    owner = "mem0ai";
    repo = "mem0";
    tag = "v${finalAttrs.version}";
    hash = "sha256-C7E7Xd1+7Vy0ZwRIjblihexQTkS2YBPx5Sogz6ACYXs=";
  };

  patches = [ ./config-file.patch ];

  dependencies =
    (with python3Packages; [
      alembic
      anthropic
      bcrypt
      cryptography
      email-validator
      fastapi
      google-genai
      passlib
      psycopg
      psycopg-pool
      pydantic
      python-dotenv
      python-jose
      slowapi
      sqlalchemy
      uvicorn
    ])
    # mem0ai also brings posthog (telemetry), unbroken there.
    ++ [ (mem0ai.override { inherit python3Packages; }) ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    app=$out/libexec/mem0-server
    mkdir -p $app $out/bin
    cp -r server/*.py server/routers server/alembic server/alembic.ini $app/
    install -m755 ${./mem0-server.py} $out/bin/mem0-server
    substituteInPlace $out/bin/mem0-server --replace-fail @app@ $app
    runHook postInstall
  '';

  # No upstream tests for the server; the NixOS VM test exercises it.
  doCheck = false;

  # Gemini provider modules import google.genai at load; fail at build time
  # instead of on the first request. Importing mem0 creates ~/.mem0.
  preFixup = ''
    export HOME=$TMPDIR
  '';
  pythonImportsCheck = [
    "mem0.llms.gemini"
    "mem0.embeddings.gemini"
  ];

  passthru = {
    category = "AI tools";
    # The monorepo also tags its SDKs and plugins (ts-v*, cli-v*, ...).
    updateScript = nix-update-script {
      extraArgs = [
        "--version-regex"
        "^v([0-9.]+)$"
      ];
    };
  };

  meta = {
    description = "Self-hosted mem0 REST API server";
    homepage = "https://github.com/mem0ai/mem0/tree/main/server";
    changelog = "https://github.com/mem0ai/mem0/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "mem0-server";
    platforms = lib.platforms.linux;
  };
})
