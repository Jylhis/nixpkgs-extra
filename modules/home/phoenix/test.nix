{
  lib,
  pkgs,
  module,
  testLib,
  extraLib,
  ...
}:
let
  inherit (testLib)
    evalHome
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  key = "/run/phoenix-api-key";

  off = evalHome [ module ];

  on = evalHome [
    module
    {
      programs.phoenix = {
        enable = true;
        apiKeyFile = key;
        endpoint = "http://phoenix.example.org:6006";
        project = "demo";
        extraEnv.ARIZE_LOG_TOOL_CONTENT = "false";
      };
    }
  ];

  withClaude = evalHome [
    module
    {
      programs.claude-code.enable = true;
      programs.phoenix = {
        enable = true;
        apiKeyFile = key;
      };
    }
  ];

  withPlugin = evalHome [
    module
    {
      programs.phoenix = {
        enable = true;
        apiKeyFile = key;
        claudePluginPackage = pkgs.hello // {
          passthru.codexNotify = "tracing-notify";
        };
      };
    }
  ];

  env = extraLib.phoenixEnv.env {
    inherit (on.programs.phoenix)
      endpoint
      project
      userId
      extraEnv
      ;
  };
in
runCases "home-phoenix" {
  off-by-default = allOf [
    (expect (!off.programs.phoenix.enable) "enabled without enable = true")
    (noFailedAssertions off)
  ];
  defaults = allOf [
    (expect (off.programs.phoenix.endpoint == "http://127.0.0.1:6006") "endpoint default")
    (expect (off.programs.phoenix.project == "agents") "project default")
    (expect (off.programs.phoenix.userId == "alice") "userId does not default to the user name")
  ];
  env-rendered = allOf [
    (noFailedAssertions on)
    (expect (env.PHOENIX_ENDPOINT == "http://phoenix.example.org:6006") "endpoint not rendered")
    (expect (env.PHOENIX_PROJECT == "demo") "project not rendered")
    (expect (env.ARIZE_USER_ID == "alice") "user id not rendered")
    (expect (env.ARIZE_LOG_TOOL_CONTENT == "false") "extraEnv not rendered")
  ];
  mcp-package-default = allOf [
    (expect (
      on.programs.phoenix.mcpPackage.pname == "phoenix-mcp"
    ) "mcpPackage does not default to the phoenix-mcp package")
    (expect (lib.hasSuffix "-phoenix-mcp-launcher" on.programs.phoenix.mcpCommand) "mcpCommand is not the launcher script")
  ];
  plugin-optional = allOf [
    (expect (on.programs.phoenix.claudePluginPackage == null) "plugin package has a default")
    (expect (on.programs.phoenix.codexNotify == null) "codexNotify set without a plugin")
    (expect (
      withPlugin.programs.phoenix.codexNotify == "tracing-notify"
    ) "codexNotify not taken from the plugin")
  ];
  claude-wrapped = allOf [
    (noFailedAssertions withClaude)
    (expect (
      lib.getName withClaude.programs.claude-code.package == lib.getName pkgs.claude-code
    ) "claude-code not wrapped with the Phoenix environment")
  ];
}
