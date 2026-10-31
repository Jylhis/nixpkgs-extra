# Arize Phoenix (`phoenix serve`): self-hosted LLM observability, packaged from
# the upstream PyPI wheel, which already carries the built React UI.
#
# Phoenix pins several libraries newer than the locked nixpkgs and needs a few
# that nixpkgs lacks (sqlean, bashkit); those are defined inline from their
# own wheels, as in ../openviking-server. sqlalchemy stays on nixpkgs' 2.0
# (upstream asks 2.1), which migrates and serves fine.
#
# The wheels are tied to CPython 3.14 (`cp314`) and x86_64 glibc; when
# nixpkgs moves python3, `pythonImportsCheck` fails and the tags need a bump.
{
  lib,
  stdenv,
  fetchurl,
  python3,
  autoPatchelfHook,
  callPackage,
  nix-update-script,
}:

let
  py = python3.pkgs;

  # Build a wheel nixpkgs does not ship or ships too old. The runtime
  # dependency gate is off because the pins cross-reference each other.
  mkWheel =
    {
      pname,
      version,
      url,
      hash,
      deps ? [ ],
      binary ? false,
      imports ? [ ],
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
      pythonImportsCheck = imports;
    };

  # Python-bundled SQLite with the sqlean extensions (regexp, time, ...),
  # imported as `sqlean` by phoenix.db.engines.
  arize-phoenix-sqlean = mkWheel {
    pname = "arize-phoenix-sqlean";
    version = "0.2.1";
    url = "https://files.pythonhosted.org/packages/e4/be/3a65c3db6ad72c68c026d8413f65ef0a6e9d7ba850e60a9b1c47cbea360f/arize_phoenix_sqlean-0.2.1-cp314-cp314-manylinux_2_28_x86_64.whl";
    hash = "sha256-GRmKGLtAx3SajohOlLMqeDno0Q2b8T3NY6LKJYrq9pQ=";
    binary = true;
    imports = [ "sqlean" ];
  };

  # Sandboxed bash for the Phoenix agent's shell tool (abi3 pyo3 wheel).
  bashkit = mkWheel {
    pname = "bashkit";
    version = "0.19.0";
    url = "https://files.pythonhosted.org/packages/2b/55/200c20eb641592efb5fb97882a191cfc2964ee6b3a2338299b8db1032b26/bashkit-0.19.0-cp39-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    hash = "sha256-tV2S7mh0dTeLGb4V+3e5+4o1T5pFfpSgjiKDhdCxfUs=";
    binary = true;
    imports = [ "bashkit" ];
  };

  graphql-core = mkWheel {
    pname = "graphql-core";
    version = "3.3.0";
    url = "https://files.pythonhosted.org/packages/0c/13/03fb01b3581134cc30d7dd3fb8a9c429267574ace881a9e72c2f57896ee9/graphql_core-3.3.0-py3-none-any.whl";
    hash = "sha256-03+sbvTfw+ql2qWdy0mNfLsRhDnSQJk8aP3cTLG63kQ=";
    imports = [ "graphql" ];
  };

  cross-web = mkWheel {
    pname = "cross-web";
    version = "0.7.0";
    url = "https://files.pythonhosted.org/packages/7a/4a/78b52ec2edcbd9b123638f4e0421fd8699ebe653ebf63ac5f82abd2665bc/cross_web-0.7.0-py3-none-any.whl";
    hash = "sha256-3eqb48aLSOrxZWGEelgxpVl4aUnFRLNwFDLgCk6NGdk=";
    deps = [ py.typing-extensions ];
  };

  strawberry-graphql = mkWheel {
    pname = "strawberry-graphql";
    version = "0.335.0";
    url = "https://files.pythonhosted.org/packages/bc/88/f8c81e01f2be2655a65804b1f9ab9b4b38578471462ce03074e37720e91c/strawberry_graphql-0.335.0-py3-none-any.whl";
    hash = "sha256-2396uryUU2fIG/w5NsWxoHGAIfxvm0EzSLptmKX/hg0=";
    deps = [
      graphql-core
      cross-web
      py.typing-extensions
      py.python-dateutil
      py.packaging
    ];
    imports = [ "strawberry" ];
  };

  sqlglot = mkWheel {
    pname = "sqlglot";
    version = "30.21.0";
    url = "https://files.pythonhosted.org/packages/7e/93/acaa0862f841051e490326c1fc8c61d618d2df26f9e7aed26c331419ab15/sqlglot-30.21.0-py3-none-any.whl";
    hash = "sha256-gW0aSBW3Vis5du/MC1Yckop0P5du/Q+4rW23pblsBp4=";
    imports = [ "sqlglot" ];
  };

  # phoenix.server.app imports `fastapi.telemetry`, new in 0.142 (nixpkgs: 0.141).
  fastapi = mkWheel {
    pname = "fastapi";
    version = "0.142.0";
    url = "https://files.pythonhosted.org/packages/7c/d6/c5bc445b65d62ee277fe1d7db068f248d4c0430791d00e095cffc7ac9245/fastapi-0.142.0-py3-none-any.whl";
    hash = "sha256-pC2lLsdE57DooOpuDLxyksbfPLvahgapGuz1wWaxVto=";
    deps = with py; [
      annotated-doc
      opentelemetry-api
      pydantic
      starlette
      typing-extensions
      typing-inspection
    ];
    imports = [ "fastapi" ];
  };

  # pydantic-ai 2.52 imports newer beta types than nixpkgs' anthropic 1.6.
  anthropic = py.anthropic.overridePythonAttrs (_: rec {
    version = "1.9.0";
    pyproject = null;
    format = "wheel";
    build-system = [ ];
    postPatch = "";
    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/15/2a/67c1b2ddf91be3112856ed74b96d1576f00dd423e4f20bb251aa144fbd6b/anthropic-${version}-py3-none-any.whl";
      hash = "sha256-p/4FqeS3IRO5NFAWmN9dVkhKyJ8FZ38PeT+L/dsVz/8=";
    };
    doCheck = false;
  });

  # Tool-annotation types phoenix.server.mcp imports; fastmcp 4 split them out
  # of `mcp`. Phoenix gets nixpkgs' fastmcp 3, which still uses `mcp.types`.
  mcp-types = mkWheel {
    pname = "mcp-types";
    version = "2.0.0";
    url = "https://files.pythonhosted.org/packages/f5/4c/c78d78c3d52b0ac594ad7cc8ef5972adfe070e3597a8a4c6ce0cd39196ea/mcp_types-2.0.0-py3-none-any.whl";
    hash = "sha256-ay3nl8onl/Vot5Up4bJZSONN5RG8wL2C/vEDmm0bjrA=";
    deps = with py; [
      pydantic
      typing-extensions
    ];
    imports = [ "mcp_types" ];
  };

  # phoenix.db.engines reaches into Connection._thread, which exists from 0.22
  # (nixpkgs: 0.21); without it the database never opens.
  aiosqlite = mkWheel {
    pname = "aiosqlite";
    version = "0.22.1";
    url = "https://files.pythonhosted.org/packages/00/b7/e3bf5133d697a08128598c8d0abc5e16377b51465a33756de24fa7dee953/aiosqlite-0.22.1-py3-none-any.whl";
    hash = "sha256-IcAC6xOCP610AZbFounY5i9iQ72efkofh/teROy0/Os=";
    imports = [ "aiosqlite" ];
  };

  # MCP 2 stack: fastmcp-slim 4 needs mcp 2 (nixpkgs: fastmcp 3 on mcp 1.29),
  # whose tool types Phoenix passes around (`mcp_types`).
  mcp = mkWheel {
    pname = "mcp";
    version = "2.0.0";
    url = "https://files.pythonhosted.org/packages/67/72/7d7897418912c1d12e87556630dfb7bf0eac71160e9bef8b447960804ee3/mcp-2.0.0-py3-none-any.whl";
    hash = "sha256-HLTHXS0se4wddWNV5dgqOfKCLMfxPiKiBR18o1kjSdY=";
    deps =
      (with py; [
        anyio
        httpx2
        jsonschema
        opentelemetry-api
        pydantic
        pyjwt
        python-multipart
        sse-starlette
        starlette
        typing-extensions
        typing-inspection
        uvicorn
      ])
      ++ [ mcp-types ];
    imports = [ "mcp" ];
  };

  fastmcp-slim = mkWheel {
    pname = "fastmcp-slim";
    version = "4.0.0";
    url = "https://files.pythonhosted.org/packages/2c/4b/7bc65d74cc93684ec8b10d49a51fa14c5e4aa3a08120c7001a85bd2a159a/fastmcp_slim-4.0.0-py3-none-any.whl";
    hash = "sha256-dSWa2AM68BH5JvS5nNqc4IC3hT+YMdOPIFajkpCOEcI=";
    deps =
      (with py; [
        authlib
        cyclopts
        exceptiongroup
        griffelib
        httpx2
        joserfc
        jsonref
        jsonschema-path
        openapi-pydantic
        opentelemetry-api
        packaging
        platformdirs
        py-key-value-aio
        pydantic-settings
        pyperclip
        python-dotenv
        python-multipart
        pyyaml
        rich
        starlette
        typing-extensions
        uncalled-for
        uvicorn
        watchfiles
        websockets
      ])
      ++ [
        mcp
        mcp-types
      ];
    imports = [ "fastmcp" ];
  };

  pydantic-graph = mkWheel {
    pname = "pydantic-graph";
    version = "2.53.0";
    url = "https://files.pythonhosted.org/packages/5c/07/6c5a2e57aad764dd81f8a8552b47ad88c598108c6794f703fe919a31bf26/pydantic_graph-2.53.0-py3-none-any.whl";
    hash = "sha256-SNcP16/+FfM3c6dLllerlEJWlyXZ5nJjrDo7ld6J9xQ=";
    deps = with py; [
      anyio
      logfire-api
      pydantic
      typing-inspection
    ];
  };

  # Upstream asks >= 2.53 with several extras; their dependencies are listed
  # explicitly.
  pydantic-ai-slim = mkWheel {
    pname = "pydantic-ai-slim";
    version = "2.53.0";
    url = "https://files.pythonhosted.org/packages/ca/6d/af87099ae2338e5bc3fae90734ef5a2121d4d582060a88a297bd109863b3/pydantic_ai_slim-2.53.0-py3-none-any.whl";
    hash = "sha256-l5+1VTzDK6+fOq7/eoPBnWzm0ZwChPXNVAh7yYcLJSI=";
    deps =
      (with py; [
        anyio
        boto3
        genai-prices
        google-genai
        griffelib
        httpx2
        openai
        opentelemetry-api
        pydantic
        starlette
        tiktoken
        typing-inspection
      ])
      ++ [
        anthropic
        fastmcp-slim
        pydantic-graph
      ];
    imports = [ "pydantic_ai" ];
  };

  # Sandbox interpreter for the MCP "code mode" (imported lazily).
  pydantic-monty-client = mkWheel {
    pname = "pydantic-monty-client";
    version = "1.1.0";
    url = "https://files.pythonhosted.org/packages/96/c0/a1a27e5488256a9b2ab6e093ef295d404c1c618d9b9b0b6aba95e3aacd20/pydantic_monty_client-1.1.0-cp314-cp314-manylinux_2_28_x86_64.whl";
    hash = "sha256-2E2l3N9V6IuEoHjrsqnCsmXC9ngFB6XZaX3KnrdB0O0=";
    deps = [ py.typing-extensions ];
    binary = true;
  };

  pydantic-monty-runtime = mkWheel {
    pname = "pydantic-monty-runtime";
    version = "1.1.0";
    url = "https://files.pythonhosted.org/packages/59/60/b2ee672278e291a05fec28f5e50906e2ccfff5899df4cd949693b495175e/pydantic_monty_runtime-1.1.0-py3-none-manylinux_2_28_x86_64.whl";
    hash = "sha256-fO5DA5JK1EqFjsPv3eQSPK2/AyyyMAai0mDHPWh0jWA=";
    binary = true;
  };

  pydantic-monty = mkWheel {
    pname = "pydantic-monty";
    version = "1.1.0";
    url = "https://files.pythonhosted.org/packages/71/3e/d54b8ad5f196efa2d8fbb664e1913b4a46677868c2402b697606ab9acce0/pydantic_monty-1.1.0-py3-none-any.whl";
    hash = "sha256-UQN+95CFNbSXlKcElLgfMr09cKV1YAsShalhpO6DgxU=";
    deps = [
      pydantic-monty-client
      pydantic-monty-runtime
    ];
  };

  phoenixLibs = {
    client = callPackage ../arize-phoenix-client/package.nix { python3Packages = py; };
    otel = callPackage ../arize-phoenix-otel/package.nix { python3Packages = py; };
    evals = callPackage ../arize-phoenix-evals/package.nix { python3Packages = py; };
  };
in
py.buildPythonApplication (finalAttrs: {
  pname = "arize-phoenix";
  version = "20.26.0";
  format = "wheel";

  src = py.fetchPypi {
    pname = "arize_phoenix";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-9XHWwiwbp27IrQaADMsdO+33oPgkJyl1AT+Xnm4xmkU=";
  };

  dependencies =
    (with py; [
      aioitertools
      alembic
      authlib
      cachetools
      certifi
      email-validator
      grpc-interceptor
      grpcio
      httpx
      h2
      jinja2
      jmespath
      joserfc
      jsonpath-ng
      jsonschema
      ldap3
      numpy
      openinference-instrumentation
      openinference-instrumentation-openai
      openinference-semantic-conventions
      opentelemetry-exporter-otlp
      opentelemetry-proto
      opentelemetry-sdk
      orjson
      pandas
      prometheus-client
      psutil
      pyarrow
      pydantic
      pystache
      python-dateutil
      python-multipart
      pyyaml
      snowballstemmer
      sqlalchemy
      starlette
      tqdm
      typing-extensions
      uvicorn
      wrapt
    ])
    ++ [
      aiosqlite
      fastmcp-slim
      pydantic-ai-slim
      anthropic
      arize-phoenix-sqlean
      bashkit
      fastapi
      graphql-core
      mcp-types
      pydantic-monty
      sqlglot
      strawberry-graphql
      phoenixLibs.client
      phoenixLibs.otel
      phoenixLibs.evals
    ];

  # Upstream pins versions newer than the locked nixpkgs.
  dontCheckRuntimeDeps = true;
  doCheck = false;

  # phoenix.config creates its working directory at import time.
  env.PHOENIX_WORKING_DIR = "/build/phoenix";

  # Upstream binds the OTLP/gRPC collector to "[::]" with no setting. Read
  # PHOENIX_GRPC_HOST instead (default unchanged); IPv6 literals need brackets.
  postInstall = ''
    substituteInPlace "$out/${py.python.sitePackages}/phoenix/server/grpc_server.py" \
      --replace-fail 'add_secure_port(f"[::]:{self._port}"' \
        'add_secure_port(f"{__import__('"'"'os'"'"').environ.get('"'"'PHOENIX_GRPC_HOST'"'"', '"'"'[::]'"'"')}:{self._port}"' \
      --replace-fail 'add_insecure_port(f"[::]:{self._port}")' \
        'add_insecure_port(f"{__import__('"'"'os'"'"').environ.get('"'"'PHOENIX_GRPC_HOST'"'"', '"'"'[::]'"'"')}:{self._port}")'
  '';

  pythonImportsCheck = [
    "phoenix.server.main"
    "phoenix.server.app"
  ];

  passthru = {
    category = "Observability";
    updateScript = nix-update-script { };
    inherit (phoenixLibs) client otel evals;
  };

  meta = {
    description = "Self-hosted LLM tracing, evaluation and prompt management from Arize";
    homepage = "https://github.com/Arize-ai/phoenix";
    changelog = "https://github.com/Arize-ai/phoenix/releases/tag/arize-phoenix-v${finalAttrs.version}";
    license = lib.licenses.elastic20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "phoenix";
    platforms = [ "x86_64-linux" ];
  };
})
