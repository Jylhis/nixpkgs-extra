# GhidraMCP: a Ghidra plugin that serves program data over loopback HTTP, and
# the `ghidra-mcp` MCP server that talks to it (or runs Ghidra headless).
#
# Since 2.0 the plugin is a standard Ghidra extension under `extension/`,
# built with Ghidra's own buildExtension.gradle (`ghidra.buildGhidraExtension`,
# so its version always matches this package set's Ghidra). `passthru.extension`
# drops into `pkgs.ghidra.withExtensions`. The MCP server is the `ghidra_mcp`
# Python package; `bridge_mcp_ghidra.py` is only a legacy shim around it.
{
  lib,
  fetchFromGitHub,
  python3,
  ghidra,
  nix-update-script,
}:
let
  version = "2.0";

  src = fetchFromGitHub {
    owner = "LaurieWired";
    repo = "GhidraMCP";
    tag = version;
    hash = "sha256-kd7ITLhjT6KJL/sWUX8ySskhZh6nCzDG6AILgtJqJPM=";
  };

  metaCommon = {
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    homepage = "https://github.com/LaurieWired/GhidraMCP";
    downloadPage = "https://github.com/LaurieWired/GhidraMCP/releases/tag/${version}";
    changelog = "https://github.com/LaurieWired/GhidraMCP/releases/tag/${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ jylhis ];
  };

  extension = ghidra.buildGhidraExtension {
    pname = "ghidra-mcp-extension";
    inherit version src;
    sourceRoot = "${src.name}/extension";

    meta = metaCommon // {
      description = "Ghidra plugin: loopback HTTP backend for the GhidraMCP server";
    };
  };
in
python3.pkgs.buildPythonApplication {
  pname = "ghidra-mcp";
  inherit version src;
  pyproject = true;

  build-system = [ python3.pkgs.hatchling ];

  # ghidra_mcp.server imports mcp.server.fastmcp, which mcp 2 removed;
  # upstream pins mcp>=1.30,<2. nixpkgs keeps 1.x as mcp_1 (1.29.0, which the
  # tests below pass on); the 1.30 floor only works around an old pydantic
  # import (LaurieWired/GhidraMCP#176).
  dependencies = with python3.pkgs; [
    mcp_1
    requests
  ];
  pythonRelaxDeps = [ "mcp" ];

  nativeCheckInputs = [ python3.pkgs.pytestCheckHook ];
  # Tests marked `ghidra` need a Ghidra installation; the rest use a fake backend.
  disabledTestMarks = [ "ghidra" ];

  pythonImportsCheck = [
    "ghidra_mcp.cli"
    "ghidra_mcp.server"
  ];

  # The pre-2.0 command name, kept for existing MCP client configs.
  postInstall = ''
    ln -s ghidra-mcp $out/bin/ghidra-mcp-bridge
  '';

  passthru = {
    category = "Reverse engineering";
    # The Ghidra plugin; drops into `pkgs.ghidra.withExtensions`.
    inherit extension;
    updateScript = nix-update-script { };
  };

  meta = metaCommon // {
    description = "MCP server exposing Ghidra reverse-engineering to LLM clients via the GhidraMCP plugin";
    mainProgram = "ghidra-mcp";
    platforms = lib.platforms.unix;
  };
}
