# Phoenix tracing for the AI processes a user runs:
#
#   Claude Code   a tracing plugin package (Arize coding-harness-tracing
#                 hooks), loaded through programs.claude-code.plugins
#   Codex         the same package's `notify` command, exposed read-only as
#                 `codexNotify` for the Codex configuration to pass along
#   MCP           `mcpCommand` is a stdio launcher of the Phoenix MCP server
#                 for harness MCP configs
#
# The hooks read PHOENIX_ENDPOINT, PHOENIX_API_KEY and PHOENIX_PROJECT from
# the environment; a Claude Code wrapper exports them. The key is read from
# its file at run time, never the store.
{
  config,
  options,
  lib,
  pkgs,
  extraPkgs,
  extraLib,
  ...
}:

let
  cfg = config.programs.phoenix;
  inherit (extraLib) phoenixEnv;

  claudeOn = config.programs.claude-code.enable;

  sharedEnv = phoenixEnv.env {
    inherit (cfg)
      endpoint
      project
      userId
      extraEnv
      ;
  };
  keyExports = phoenixEnv.keyExports { inherit (cfg) apiKeyFile; };

  setDefaults = lib.mapAttrsToList (
    n: v: "--set-default ${lib.escapeShellArg n} ${lib.escapeShellArg v}"
  ) sharedEnv;

  # Keeps name and version so version-gated consumers (HM claude-code) still
  # see them.
  withPhoenixEnv =
    pkg:
    pkgs.symlinkJoin {
      inherit (pkg) name meta;
      version = lib.getVersion pkg;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram "$out/bin/${pkg.meta.mainProgram}" \
          --run ${lib.escapeShellArg keyExports} \
          ${lib.concatStringsSep " " setDefaults}
      '';
    };

  # Older home-manager releases type claude-code.plugins as a list; current
  # unstable takes named plugins. Handle both shapes.
  claudePlugins =
    if builtins.isList options.programs.claude-code.plugins.default then
      [ cfg.claudePluginPackage ]
    else
      { phoenix-harness-tracing = cfg.claudePluginPackage; };
in
{
  options.programs.phoenix = {
    enable = lib.mkEnableOption ''
      Phoenix tracing of every enabled AI process. Sends prompts, model
      output and tool input/output to {option}`programs.phoenix.endpoint`'';

    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:6006";
      description = "Phoenix base URL (the hooks append `/v1/traces`).";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/secrets/phoenix-api-key";
      description = "File holding the Phoenix system API key, read at run time.";
    };

    project = lib.mkOption {
      type = lib.types.str;
      default = "agents";
      description = "Phoenix project that receives the traces (PHOENIX_PROJECT).";
    };

    userId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = config.home.username;
      defaultText = lib.literalExpression "config.home.username";
      description = "User id attached to every trace (ARIZE_USER_ID); null to omit.";
    };

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        ARIZE_LOG_TOOL_CONTENT = "false";
      };
      description = "Extra non-secret variables for the wrapped harnesses.";
    };

    claudePluginPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        The Claude Code tracing plugin (Arize coding-harness-tracing); it
        also provides the Codex notify command through
        `passthru.codexNotify`. Not shipped by this repository: without it
        Claude Code is only wrapped with the Phoenix environment, loads no
        plugin, and {option}`programs.phoenix.codexNotify` is unavailable.
      '';
    };

    mcpPackage = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.phoenix-mcp;
      defaultText = lib.literalExpression "pkgs.phoenix-mcp";
      description = "The Phoenix MCP server.";
    };

    codexNotify = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if cfg.claudePluginPackage == null then null else cfg.claudePluginPackage.passthru.codexNotify;
      defaultText = lib.literalExpression "config.programs.phoenix.claudePluginPackage.passthru.codexNotify";
      readOnly = true;
      description = ''
        Codex `notify` command that sends a turn to Phoenix; null while no
        {option}`programs.phoenix.claudePluginPackage` is set.
      '';
    };

    mcpCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.writeShellScript "phoenix-mcp-launcher" ''
        ${keyExports}
        ${phoenixEnv.defaultExports { inherit (sharedEnv) PHOENIX_ENDPOINT PHOENIX_PROJECT; }}
        exec ${lib.getExe cfg.mcpPackage} "$@"
      ''}";
      defaultText = lib.literalMD "a launcher script that exports the API key and endpoint, then runs {option}`programs.phoenix.mcpPackage`";
      readOnly = true;
      description = "Stdio launcher of the Phoenix MCP server for harness MCP configs.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.claude-code = lib.mkIf claudeOn (
      {
        package = withPhoenixEnv pkgs.claude-code;
      }
      // lib.optionalAttrs (cfg.claudePluginPackage != null) { plugins = claudePlugins; }
    );
  };
}
