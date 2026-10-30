# Shared schema and helpers for the OpenViking server modules.
#
# Used by modules/nixos/openviking-server and modules/home/openviking-server
# so the ov.conf schema and CLI invocation stay in sync.
{ lib }:
let
  inherit (lib)
    filterAttrs
    getExe
    mkOption
    optionalAttrs
    optionals
    types
    ;

  # Drop attrs whose value is null so optional fields never reach the JSON.
  pruneNull = filterAttrs (_: v: v != null);

  # Map a provider sub-option (camelCase) to OpenViking's snake_case
  # connection fields, omitting anything left null. max_concurrent is added
  # by the caller because embedding and vlm place it at different levels.
  providerBlock =
    p:
    pruneNull {
      inherit (p) provider model;
      api_base = p.apiBase;
      api_key = p.apiKey or null;
      dimension = p.dimension or null;
    };

  # Failover list: the primary, then `fallback`. Rendered only when a fallback
  # is set, so configs without one stay byte-identical. Credentials carry no
  # dimension (the parent's wins), so both entries share one vector schema.
  withFallback =
    p:
    optionalAttrs ((p.fallback or null) != null) {
      credentials = [
        (removeAttrs (providerBlock p) [ "dimension" ] // { id = "primary"; })
        (pruneNull {
          id = "fallback";
          inherit (p.fallback) provider model;
          api_base = p.fallback.apiBase;
          api_key = p.fallback.apiKey;
          extra_request_body =
            if (p.fallback.extraRequestBody or { }) == { } then null else p.fallback.extraRequestBody;
        })
      ];
    };
in
{
  inherit pruneNull;

  # Build the ov.conf JSON structure (an attrset; callers run builtins.toJSON).
  mkOvConf =
    {
      workspace,
      logLevel ? "INFO",
      logOutput ? "stdout",
      embedding,
      vlm,
      queryPlanner ? null,
      rerank ? null,
      botAgentModel ? null,
      extra ? { },
    }:
    {
      storage.workspace = workspace;
      log = {
        level = logLevel;
        output = logOutput;
      };
      # Provider fields nest under `dense`; max_concurrent and
      # max_input_tokens sit at the embedding level (0.5.1 ignores them in
      # dense). allow_metadata_override lets the server adopt an existing
      # collection with differing provider metadata but the same dimension.
      embedding = {
        max_concurrent = embedding.maxConcurrent or 4;
        allow_metadata_override = embedding.allowMetadataOverride or false;
        dense = providerBlock embedding // withFallback embedding;
      }
      // pruneNull { max_input_tokens = embedding.maxInputTokens or null; };
      # vlm keeps its provider fields flat, with max_concurrent alongside.
      vlm =
        providerBlock vlm
        // withFallback vlm
        // {
          max_concurrent = vlm.maxConcurrent or 4;
        }
        // optionalAttrs ((vlm.timeout or null) != null) { inherit (vlm) timeout; };
    }
    # query_planner only when set; the server falls back to `vlm` when the
    # section is absent.
    // optionalAttrs (queryPlanner != null) {
      query_planner = providerBlock queryPlanner;
    }
    # Rerank only when set; api_base is the full endpoint URL.
    // optionalAttrs (rerank != null) {
      inherit rerank;
    }
    # vikingbot agent model. An explicit bot.agents.model stops inheriting the
    # root vlm; provider/api_base mirror the vlm option.
    // optionalAttrs (botAgentModel != null) {
      bot.agents = providerBlock vlm // {
        model = botAgentModel;
      };
    }
    // extra;

  # ExecStart argument vector for openviking-server. Callers wrap the result
  # with lib.escapeShellArgs.
  mkExecArgs =
    {
      package,
      host,
      port,
      configFile ? null,
    }:
    [
      (getExe package)
      "--host"
      host
      "--port"
      (toString port)
    ]
    ++ optionals (configFile != null) [
      "--config"
      (toString configFile)
    ];

  # Option declarations shared by the system and user modules.
  commonServiceOptions =
    { extraPkgs }:
    {
      package = mkOption {
        type = types.package;
        default = extraPkgs.openviking-server;
        defaultText = lib.literalExpression "pkgs.openviking-server";
        description = "The openviking-server package to run.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = ''
          Address the server binds to (passed as `--host`). Defaults to
          loopback.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 1933;
        description = "TCP port the server binds to (passed as `--port`).";
      };

      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/ov.conf";
        description = ''
          Path to an OpenViking `ov.conf` (JSON) describing storage, logging,
          embedding and VLM providers. Passed as `--config`. When set it takes
          precedence over any structured config the module would build.
        '';
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        example = lib.literalExpression ''{ OPENVIKING_PUBLIC_BASE_URL = "https://ov.example.org"; }'';
        description = "Extra environment variables for the server unit.";
      };

      environmentFiles = mkOption {
        type = types.listOf types.path;
        default = [ ];
        description = ''
          EnvironmentFiles for the unit (e.g. a secret-manager-rendered file),
          read at start without entering the store.
        '';
      };
    };
}
