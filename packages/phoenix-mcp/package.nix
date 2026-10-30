# Arize Phoenix MCP server, from the published npm tarball, which holds the
# compiled `build/`; the upstream source is a pnpm monorepo. The tarball ships
# no lockfile: `package-lock.json` is generated from its production
# `dependencies` (`npm install --package-lock-only`); refresh on version bumps.
{
  lib,
  fetchurl,
  jq,
  buildNpmPackage,
  nix-update-script,
}:

buildNpmPackage (finalAttrs: {
  pname = "phoenix-mcp";
  version = "4.3.17";

  src = fetchurl {
    url = "https://registry.npmjs.org/@arizeai/phoenix-mcp/-/phoenix-mcp-${finalAttrs.version}.tgz";
    hash = "sha512-9tv54LS3BhfVrSxGrtg0bjv2DwQ7HTa/XtZPh8Yjm70kPk38NokqmKP2ap4i/jWWOG2PxConNCrO23hnNa22nA==";
  };
  sourceRoot = "package";

  # Upstream's bin key is the scoped package name, which installs as a
  # directory. Drop the dev dependencies and scripts the lockfile was
  # generated without. jq by store path: the npm-deps fetcher runs this too,
  # without nativeBuildInputs.
  postPatch = ''
    cp ${./package-lock.json} package-lock.json
    ${lib.getExe jq} 'del(.devDependencies, .scripts) | .bin = { "phoenix-mcp": "./build/index.js" }' \
      package.json > package.json.new
    mv package.json.new package.json
  '';

  npmDepsHash = "sha256-nzfyhSPTzIH0EhqiI14XbKVNAf0pu8XyGD8ayORkJRw=";
  dontNpmBuild = true;

  # The server has no --help; an MCP initialize over stdio proves it starts.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"check","version":"0"}}}' \
      | $out/bin/phoenix-mcp --baseUrl http://127.0.0.1:9 | grep -q phoenix-mcp-server
    runHook postInstallCheck
  '';

  passthru = {
    category = "Observability";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Model Context Protocol server for Arize Phoenix";
    homepage = "https://github.com/Arize-ai/phoenix/tree/main/js/packages/phoenix-mcp";
    changelog = "https://github.com/Arize-ai/phoenix/releases";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
    mainProgram = "phoenix-mcp";
  };
})
