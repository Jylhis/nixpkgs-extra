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
  version = "1.13.0";

  src = fetchgit {
    url = "https://github.com/OpenHands/OpenHands.git";
    tag = "v${version}";
    hash = "sha256-vZ/6KVO1HXLRpn20OVCIh3akJAj5KSKSD3pkjjBxbuQ=";
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

  # agent-client-protocol: upstream pins acp<0.11 (0.11 reordered prompt()
  # args and breaks the SDK's ACP client); take 0.10.1 from its own wheel.
  agent-client-protocol = mkWheel {
    pname = "agent-client-protocol";
    version = "0.10.1";
    url = "https://files.pythonhosted.org/packages/7b/18/d8c7ff337cf621ea79a84006a7252ff057bfb5767549bb102cc6649f4ec2/agent_client_protocol-0.10.1-py3-none-any.whl";
    hash = "sha256-oD0xmPTXcvLg7AEsAKwczhMbRxAiCj3J+uPJkdBHx1A=";
    deps = [ py.pydantic ];
  };

  # openhands-sdk. lmnr is imported lazily, only with LMNR_* env, so omitted.
  openhands-sdk = mkWheel {
    pname = "openhands-sdk";
    version = "1.42.1";
    url = "https://files.pythonhosted.org/packages/ec/40/cad4dc348017c3c292804acca04e8c75da726c7631bf8de48d9e7c6dc130/openhands_sdk-1.42.1-py3-none-any.whl";
    hash = "sha256-EK89bK8Qdey7hSDbEVDA7AF57jUrGfA5XSJzr9pgBNI=";
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
    version = "1.42.1";
    url = "https://files.pythonhosted.org/packages/58/51/b3c3f1a0375ce88a9befa73e6ee0212efb0e08a16de122cbd19274d8b1b0/openhands_tools-1.42.1-py3-none-any.whl";
    hash = "sha256-ONY8jzFv3Sc2SpaiqH4cCQ/NTRBW3gJpnkoWA0WYUQY=";
    deps = [
      openhands-sdk
    ]
    ++ (with py; [
      binaryornot
      cachetools
      func-timeout
      libtmux
      pydantic
      tree-sitter
      tree-sitter-bash
    ]);
  };

  openhands-agent-server = mkWheel {
    pname = "openhands-agent-server";
    version = "1.42.1";
    url = "https://files.pythonhosted.org/packages/72/8c/e3e28a7051191f9dc319efc205c257646896a62c249cb165f74bddf151be/openhands_agent_server-1.42.1-py3-none-any.whl";
    hash = "sha256-dypzsZaErKtfn2GxwkTxVgUmJa3lGl5IpCSzwTA596c=";
    deps = [
      openhands-sdk
    ]
    ++ (with py; [
      aiosqlite
      alembic
      docker
      fastapi
      openai
      pydantic
      sqlalchemy
      uvicorn
      websockets
      wsproto
    ]);
  };

  openhands-workspace = mkWheel {
    pname = "openhands-workspace";
    version = "1.42.1";
    url = "https://files.pythonhosted.org/packages/cc/1f/2ef9b56751b64a65a798c46a77e66ce3f8506fbd061bdb07c5bef6e4440b/openhands_workspace-1.42.1-py3-none-any.whl";
    hash = "sha256-f2MsqxsABcemI+rho//S4bkVb/yV2H47z3CY+C6uHl0=";
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
    version = "1.7.1";
    url = "https://files.pythonhosted.org/packages/48/87/a727538e902bb5f28ea1396e8a0b33ec3758dd405abaa5c54422c9d0fc18/openhands_automation-1.7.1-py3-none-any.whl";
    hash = "sha256-BoP4L1HorJ1yZwUfNilJwLHmMvrcFZnwUyI8RYbB7KA=";
    deps = [
      openhands-sdk
      openhands-workspace
    ]
    ++ (with py; [
      aiosqlite
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
      sqlalchemy
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
  npmDepsHash = "sha256-B0I0yHgVzPFPVI7DPp8PwPuQdrym77d3Sx/QgQBPiOI=";

  nativeBuildInputs = [ makeWrapper ];

  # The upstream `prepare` script runs husky, which fails outside a git
  # checkout; HUSKY=0 turns it into a no-op.
  env.HUSKY = "0";

  # prefetch-npm-deps rejects missing integrity fields. Drop the bundled
  # wasm32-wasi fallback dependencies and restore @babel/runtime's integrity.
  postPatch = ''
    ${lib.getExe jq} '(.packages |= with_entries(
           select(.key | contains("oxide-wasm32-wasi/node_modules/") | not)))
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
