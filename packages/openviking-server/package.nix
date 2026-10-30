# OpenViking server, packaged from the upstream PyPI wheel.
#
# Unlike the `ov` CLI (the `openviking` package, built from Rust source), the
# server's native pieces (`ragfs_python`, the C++ vector-db engine, the
# web-studio SPA) are prebuilt in the manylinux wheel; building them needs
# Rust 1.91, cmake and Node. The bundled `.so`s are patchelf'd instead.
#
# Runtime dependencies missing from nixpkgs (Volcengine SDKs, lark-oapi, one
# OTel instrumentation package) are defined inline from their own wheels.
{
  lib,
  stdenv,
  fetchurl,
  fetchPypi,
  python3,
  autoPatchelfHook,
  nix-update-script,
}:

let
  py = python3.pkgs;

  # Build a wheel nixpkgs does not ship. Runtime dep-pin checks are off because
  # upstream pins versions newer than nixpkgs carries.
  mkWheel =
    {
      pname,
      version,
      url,
      hash,
      deps ? [ ],
      binary ? false,
    }:
    py.buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = fetchurl { inherit url hash; };
      dependencies = deps;
      dontCheckRuntimeDeps = true;
      doCheck = false;
      nativeBuildInputs = lib.optionals binary [ autoPatchelfHook ];
      buildInputs = lib.optionals binary [ stdenv.cc.cc.lib ];
      pythonImportsCheck = [ ];
    };

  volcengine = mkWheel {
    pname = "volcengine";
    version = "1.0.223";
    url = "https://files.pythonhosted.org/packages/ef/40/a3d894a644a17f57fdb371bfdcc5d0a0a12284f864c80fec7721b445557c/volcengine-1.0.223-py3-none-any.whl";
    hash = "sha256-qWzOnjkyhdgzi4v2lGhDYVA+6pKWImDCw5rTzzpKCMw=";
    deps = with py; [
      requests
      six
      pytz
      protobuf
      retry
      google-auth
    ];
  };

  volcengine-python-sdk = mkWheel {
    pname = "volcengine-python-sdk";
    version = "5.0.34";
    url = "https://files.pythonhosted.org/packages/c1/7b/e106e6855ceacdfe089a2e17e9c1862d790eb28905a827ee1aaa36fe40be/volcengine_python_sdk-5.0.34-py2.py3-none-any.whl";
    hash = "sha256-4kP8B3zMJcN/66m5MD7n1oF8kMqhwXzImE2dT4QQmxU=";
    deps = with py; [
      certifi
      python-dateutil
      six
      urllib3
      pydantic
      anyio
      httpx
    ];
  };

  lark-oapi = mkWheel {
    pname = "lark-oapi";
    version = "1.6.8";
    url = "https://files.pythonhosted.org/packages/4a/ad/1ab04db5d549ad1a7a2cd33682b1c38dee1d65019cb24fd7a23270e6337d/lark_oapi-1.6.8-py3-none-any.whl";
    hash = "sha256-m0Q6XUen0gTdQtxAiWyLdQh8w1eI5FxIwUCAbX335eg=";
    deps = with py; [
      requests
      requests-toolbelt
      pycryptodome
    ];
  };

  opentelemetry-instrumentation-asyncio = mkWheel {
    pname = "opentelemetry-instrumentation-asyncio";
    version = "0.63b1";
    url = "https://files.pythonhosted.org/packages/28/25/c98e90c803b3f9bcf1c1e8b1284d022f2894d45f2d350f8c64f75209523c/opentelemetry_instrumentation_asyncio-0.63b1-py3-none-any.whl";
    hash = "sha256-C6qAyTFFafu4aOB/C4E22jZyA8KULfWBPBhL3iU39Eo=";
    deps = with py; [
      opentelemetry-api
      opentelemetry-instrumentation
    ];
  };

  # The vendored `openviking_cli` shim subclasses `openviking_sdk.AsyncHTTPClient`
  # via a lazy import that pythonImportsCheck misses; without the SDK the
  # server dies on the first session import.
  openviking-sdk = mkWheel {
    pname = "openviking-sdk";
    version = "0.1.9";
    url = "https://files.pythonhosted.org/packages/47/d6/aa82551f9c5d06ce682b9194c784beeb16478ce103d650ed8e8b487b1aa7/openviking_sdk-0.1.9-py3-none-any.whl";
    hash = "sha256-YFfzq5Ic7kaXp7QklINHZpy3uOBEOfMFUD2KtxMq884=";
    deps = with py; [ httpx ];
  };
in
py.buildPythonApplication (finalAttrs: {
  pname = "openviking-server";
  version = "0.5.2.1";
  format = "wheel";

  # fetchPypi so nix-update can repin the hash from just the version. The PyPI
  # project is `openviking`, so pname is set explicitly.
  src = fetchPypi {
    inherit (finalAttrs) version;
    pname = "openviking";
    format = "wheel";
    dist = "cp310";
    python = "cp310";
    abi = "abi3";
    platform = "manylinux_2_31_x86_64";
    hash = "sha256-6Lc6v8oc60XFin+SsY6ZKbs61hHT/WFCJlq+elNIgMw=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  # Upstream pins versions newer than nixpkgs; the wheel runs fine against the
  # older libs.
  dontCheckRuntimeDeps = true;

  dependencies = [
    volcengine
    volcengine-python-sdk
    lark-oapi
    opentelemetry-instrumentation-asyncio
    openviking-sdk
  ]
  ++ (with py; [
    pydantic
    typing-extensions
    pyyaml
    httpx
    pdfplumber
    readabilipy
    markdownify
    openai
    requests
    python-docx
    olefile
    xlrd
    python-pptx
    openpyxl
    ebooklib
    json-repair
    apscheduler
    fastapi
    uvicorn
    xxhash
    jinja2
    tabulate
    urllib3
    protobuf
    pdfminer-six
    typer
    litellm
    python-multipart
    tree-sitter
    tree-sitter-language-pack
    opentelemetry-api
    opentelemetry-sdk
    opentelemetry-exporter-otlp-proto-grpc
    opentelemetry-exporter-otlp-proto-http
    loguru
    cryptography
    argon2-cffi
    mcp
    pathspec
    # rapidfuzz: session.memory.merge_op.patch_handler top-level import,
    # new in 0.4.23 (pythonImportsCheck catches its absence at build).
    rapidfuzz
  ])
  # openviking[bot] extra, for the `vikingbot` gateway child spawned by
  # `--with-bot`. The other upstream extra deps are omitted: vikingbot imports
  # them lazily per channel/backend and they are not in nixpkgs.
  ++ (with py; [
    # prompt-toolkit: vikingbot/cli/commands.py top-level import
    prompt-toolkit
    # croniter: vikingbot cron service, always started by the gateway
    croniter
    # pydantic-settings: vikingbot config schema (BaseSettings)
    pydantic-settings
    websockets
    websocket-client
    python-socketio
    python-engineio
    socksio
    python-socks
    msgpack
    html2text
    readability-lxml
    beautifulsoup4
    ddgs
    langfuse
    py-machineid
    python-telegram-bot
    slack-sdk
  ]);

  # Import the server and bot modules too: they pull the full runtime dep
  # chain, so a bump that adds a dep fails here instead of at runtime.
  pythonImportsCheck = [
    "openviking"
    "openviking.server.app"
    "vikingbot.cli.commands"
  ];

  # nix-update bumps `version` and the wheel hash. Versions come from the
  # GitHub `v`-tags (`--url`) because its PyPI fetcher does not understand
  # fetchPypi's wheel URL. The `mkWheel` deps above are not bumped: reconcile
  # them by hand until `pythonImportsCheck` passes.
  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--url"
      "https://github.com/volcengine/OpenViking"
      "--version-regex"
      "^v([0-9.]+)$"
    ];
  };

  passthru.category = "AI tools";

  meta = {
    description = "Server for OpenViking, a context filesystem for AI agents";
    homepage = "https://openviking.ai";
    changelog = "https://github.com/volcengine/OpenViking/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "openviking-server";
    maintainers = with lib.maintainers; [ jylhis ];
    sourceProvenance = with lib.sourceTypes; [
      binaryNativeCode
      binaryBytecode
    ];
    platforms = [ "x86_64-linux" ];
  };
})
