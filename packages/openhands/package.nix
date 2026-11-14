{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  fetchgit,
  fetchurl,
  jq,
  nodejs_22,
  makeWrapper,
  python3,
  git,
  nix-update-script,
}:

let
  version = "1.40.0";

  src = fetchgit {
    url = "https://github.com/OpenHands/OpenHands.git";
    tag = "v${version}";
    hash = "sha256-2wBUVpgw3Nv/1oVy/OQr5rA0Eo+zzgYjnsKHB23aIsM=";
  };

  # nixpkgs moved mcp to 2.x and marks fastmcp-slim (hence fastmcp, which
  # openhands-sdk needs) broken against it. Pin mcp 1.x until fastmcp supports 2.
  python = python3.override {
    self = python;
    packageOverrides = _: prev: {
      mcp = prev.mcp.overridePythonAttrs (old: rec {
        version = "1.30.0";
        src = fetchFromGitHub {
          owner = "modelcontextprotocol";
          repo = "python-sdk";
          tag = "v${version}";
          hash = "sha256-EkmTqsK+vBJcURuwFkhtNJMFgtzgw/7Cd+Fpav4P/ko=";
        };
        dependencies =
          (with prev; [
            anyio
            httpx
            httpx-sse
            jsonschema
            pydantic
            pydantic-settings
            pyjwt
            python-multipart
            sse-starlette
            starlette
            typing-extensions
            typing-inspection
            uvicorn
          ])
          ++ prev.pyjwt.optional-dependencies.crypto;
        doCheck = false;
        nativeCheckInputs = [ ];
      });
      # fastmcp-slim is marked broken against mcp 2; it works with mcp 1, so
      # lift the flag. fastmcp's own suite has a storage-shape failure here.
      fastmcp-slim = prev.fastmcp-slim.overridePythonAttrs (old: {
        meta = old.meta // {
          broken = false;
        };
      });
      fastmcp = prev.fastmcp.overridePythonAttrs { doCheck = false; };
    };
  };
  py = python.pkgs;

  # Build a PyPI wheel nixpkgs does not ship. Runtime dep-pin checks are off
  # because upstream pins newer versions than nixpkgs carries.
  mkWheel =
    {
      pname,
      version,
      url,
      hash,
      deps ? [ ],
    }:
    py.buildPythonPackage {
      inherit pname version;
      format = "wheel";
      src = fetchurl { inherit url hash; };
      dependencies = deps;
      dontCheckRuntimeDeps = true;
      doCheck = false;
      pythonImportsCheck = [ ];
    };

  # agent-client-protocol: the SDK needs >=0.12.1,<0.13, newer than nixpkgs.
  agent-client-protocol = mkWheel {
    pname = "agent-client-protocol";
    version = "0.12.1";
    url = "https://files.pythonhosted.org/packages/21/61/0a2186c8ca53cf464767d4c4fb7fd9e23f48ce4547c2fa0d1c83a4d52410/agent_client_protocol-0.12.1-py3-none-any.whl";
    hash = "sha256-qvPMMB7YfZ4sTMuRrf4c1YeENV9s5+UT9Q58ojkYYu8=";
    deps = [ py.pydantic ];
  };

  # openhands-sdk. lmnr is imported lazily, only with LMNR_* env, so omitted.
  openhands-sdk = mkWheel {
    pname = "openhands-sdk";
    version = "1.62.0";
    url = "https://files.pythonhosted.org/packages/81/d5/f4aa93b38330f280966faaad78279af618f1b54c79cf6dec88c17fefe8b8/openhands_sdk-1.62.0-py3-none-any.whl";
    hash = "sha256-H/CD9b/2CQxuPwU27S0+r/IUVTbOVMvPUPNWYWdYcGU=";
    deps = [
      agent-client-protocol
    ]
    ++ (with py; [
      deprecation
      fakeredis
      fastmcp
      filelock
      httpx
      jsonschema
      joserfc
      litellm
      pillow
      pydantic
      python-frontmatter
      python-json-logger
      tenacity
      tree-sitter
      tree-sitter-bash
      websockets
    ]);
  };

  # openhands-tools. browser-use and tom-swe are imported lazily and pull
  # heavy trees, so they are omitted.
  openhands-tools = mkWheel {
    pname = "openhands-tools";
    version = "1.62.0";
    url = "https://files.pythonhosted.org/packages/f7/a5/6fa1386eeef2c614c2eb1c121784c83a6f7631822c538bd394bf398a1448/openhands_tools-1.62.0-py3-none-any.whl";
    hash = "sha256-pMoQCdUOn7y1Y5BLQ5LFLdW4ViMxOCsCKE01VOzrNpk=";
    deps = [
      openhands-sdk
    ]
    ++ (with py; [
      binaryornot
      cachetools
      func-timeout
      libtmux
      psutil
      pydantic
      tree-sitter
      tree-sitter-bash
    ]);
  };

  openhands-agent-server = mkWheel {
    pname = "openhands-agent-server";
    version = "1.62.0";
    url = "https://files.pythonhosted.org/packages/e8/a9/16c018d532c56d4954368344495db3bc7746db40104325de55239932b7cd/openhands_agent_server-1.62.0-py3-none-any.whl";
    hash = "sha256-5N9qrLV8IJ1xrqJnOWV90Qw2xfSS8VWxbMEqYiSvsp8=";
    deps = [
      openhands-sdk
    ]
    ++ (with py; [
      aiosqlite
      alembic
      docker
      fastapi
      openai
      opentelemetry-sdk
      pydantic
      sqlalchemy
      uvicorn
      websockets
      wsproto
    ]);
  };

  openhands-workspace = mkWheel {
    pname = "openhands-workspace";
    version = "1.62.0";
    url = "https://files.pythonhosted.org/packages/3d/9f/c0dd82a8ce87b1df3d29c299bd62d606cb1cd38ac50f4b81d2adb650c3b6/openhands_workspace-1.62.0-py3-none-any.whl";
    hash = "sha256-y7ZBXlm/37mSK4K5PzuvWl7Y8Ozje7aV88B9kTzou5Q=";
    deps = [
      openhands-sdk
      openhands-agent-server
      py.pydantic
    ];
  };

  # openhands-automation. cloud-sql-python-connector (GCP only, imported
  # lazily) is omitted.
  openhands-automation = mkWheel {
    pname = "openhands-automation";
    version = "1.32.1";
    url = "https://files.pythonhosted.org/packages/a6/76/5f648e928577db4ef75774ea13b75b7e3cff4b6fec83c848ff052d5dc0aa/openhands_automation-1.32.1-py3-none-any.whl";
    hash = "sha256-TqqZF/iOU8+95HwwImXmHdaS4/iLJC7J7vqn0pAbOBs=";
    deps = [
      openhands-sdk
      openhands-workspace
    ]
    ++ (with py; [
      aiosqlite
      aiohttp
      alembic
      asyncpg
      boto3
      cachetools
      croniter
      fastapi
      google-cloud-storage
      httpx
      jmespath
      pg8000
      prometheus-client
      pydantic
      pydantic-settings
      pyjwt
      python-json-logger
      pyyaml
      slack-sdk
      sqlalchemy
      starlette
      tenacity
      tzdata
      uvicorn
    ]);
  };

  # One env exposing `agent-server` and `uvicorn` (openhands.automation.app:app).
  pythonEnv = python.withPackages (_: [
    openhands-agent-server
    openhands-tools
    openhands-workspace
    openhands-automation
  ]);

  agentServerBin = "${pythonEnv}/bin/agent-server";
  uvicornBin = "${pythonEnv}/bin/uvicorn";
in
buildNpmPackage {
  pname = "openhands";
  inherit version src;
  __structuredAttrs = true;

  # Node major required by engines (>= 22.12.0); also on the runtime PATH.
  nodejs = nodejs_22;

  # Hash of the npm dependency closure from the fixed-up package-lock.json;
  # refresh with `lib.fakeHash` if the pin or lockfile changes.
  npmDepsHash = "sha256-JA50BWVitsk6burNjyBT85wq5T2FRlwD1pef/F7z3iQ=";

  nativeBuildInputs = [ makeWrapper ];

  # The upstream `prepare` script runs husky, which fails outside a git
  # checkout; HUSKY=0 turns it into a no-op.
  env.HUSKY = "0";

  # prefetch-npm-deps rejects missing integrity fields. Drop the bundled
  # wasm32-wasi fallback dependencies and restore @babel/runtime's integrity.
  # Drop @eslint/js's optional peer on eslint ^10 (locked eslint is 9.39.5):
  # npm would re-resolve it from the registry, which is offline.
  postPatch = ''
    ${lib.getExe jq} '(.packages |= with_entries(
           select(.key | contains("oxide-wasm32-wasi/node_modules/") | not)))
        | del(.packages["node_modules/@eslint/js"].peerDependencies,
               .packages["node_modules/@eslint/js"].peerDependenciesMeta)
        | .packages["node_modules/@babel/runtime"].integrity =
            "sha512-Nq8OhGWiZIZGV6hLHoyAKLLcJihP/xFeBMGJoUrxTX2psI8dCifzLhZISFb+VWS3wFMRDmCGw5R+dOySCqPLhw=="' \
      package-lock.json > package-lock.json.tmp
    mv package-lock.json.tmp package-lock.json
  '';

  # Rewrite the `uvx` command builders and the launcher's uvx check to run the
  # Nix-built binaries. Not in postPatch, so fetching npm deps needs no Python.
  postConfigure = ''
    substituteInPlace scripts/dev-safe.mjs \
      --replace-fail 'command: "uvx",' 'command: "${agentServerBin}",' \
      --replace-fail 'args: uvxArgs,' 'args: [],'

    substituteInPlace scripts/dev-with-automation.mjs \
      --replace-fail 'command: "uvx",' 'command: "${uvicornBin}",' \
      --replace-fail 'args: uvxArgs,' 'args: ["openhands.automation.app:app"],' \
      --replace-fail 'checkUvx: !args.frontendOnly,' 'checkUvx: false,'
  '';

  # `build` == `build:app` == `make-i18n && react-router build` (-> build/).
  npmBuildScript = "build";

  # An application, not a library: install the built tree and wrap the
  # launcher with node/git/python on PATH.
  dontNpmInstall = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/openhands"
    cp -r . "$out/libexec/openhands/"

    makeWrapper ${nodejs_22}/bin/node "$out/bin/openhands" \
      --add-flags "$out/libexec/openhands/bin/agent-canvas.mjs" \
      --prefix PATH : ${
        lib.makeBinPath [
          nodejs_22
          git
          pythonEnv
        ]
      }
    ln -s "$out/bin/openhands" "$out/bin/agent-canvas"

    runHook postInstall
  '';

  passthru = {
    inherit pythonEnv;
    category = "AI tools";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "AI software engineering agent with the Agent Canvas web interface";
    homepage = "https://github.com/OpenHands/OpenHands";
    changelog = "https://github.com/OpenHands/OpenHands/releases/tag/v${version}";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
    mainProgram = "openhands";
  };
}
