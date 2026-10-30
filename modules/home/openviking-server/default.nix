# Runs the OpenViking server (`ov` CLI on :1933) as a per-user systemd
# service with state under the XDG data dir, bound to loopback.
#
# Linux-only: upstream ships an x86_64 manylinux wheel, so no launchd variant.
# The runner injects the API key from `apiKeyFile` at start.
{
  config,
  lib,
  pkgs,
  extraPkgs,
  extraLib,
  ...
}:
let
  ov = extraLib.openviking;
  cfg = config.programs.openviking-server;
  inherit (pkgs.stdenv.hostPlatform) isLinux;
  inherit (ov) pruneNull;

  providerCommon = {
    provider = lib.mkOption {
      type = lib.types.str;
      default = "openai";
      description = "Provider client OpenViking uses (`openai` selects the OpenAI-compatible HTTP client).";
    };
    apiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://openrouter.ai/api/v1";
      description = "Base URL of the OpenAI-compatible endpoint.";
    };
    apiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Literal API key. Insecure: it lands in the Nix store. Prefer
        leaving this null and setting `apiKeyFile`, which the runner injects
        at start.
      '';
    };
    maxConcurrent = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4;
      description = "Maximum concurrent requests to the provider.";
    };
  };

  # Second entry of an ov.conf `credentials` failover list (used on
  # connection errors, 429 and 5xx; primary returns after 600 s).
  fallbackOptions = {
    provider = lib.mkOption {
      type = lib.types.str;
      default = "openai";
      description = "Provider client for the fallback endpoint.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      description = "Model id at the fallback endpoint.";
    };
    apiBase = lib.mkOption {
      type = lib.types.str;
      default = "https://openrouter.ai/api/v1";
      description = "Base URL of the fallback OpenAI-compatible endpoint.";
    };
    apiKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Literal API key. Insecure: prefer fallbackApiKeyFile.";
    };
  };

  embeddingFallbackType = lib.types.submodule { options = fallbackOptions; };

  vlmFallbackType = lib.types.submodule {
    options = fallbackOptions // {
      extraRequestBody = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Extra JSON merged into each request body (`extra_request_body`).";
      };
    };
  };

  fallbackOption =
    type:
    lib.mkOption {
      type = lib.types.nullOr type;
      default = null;
      description = ''
        Failover endpoint tried when the primary fails. Null renders no
        `credentials` list, so the server uses the primary alone. Only
        `embedding` and `vlm` render it; `queryPlanner` ignores it.
      '';
    };

  embeddingType = lib.types.submodule {
    options = providerCommon // {
      fallback = fallbackOption embeddingFallbackType;
      model = lib.mkOption {
        type = lib.types.str;
        default = "openai/text-embedding-3-small";
        description = "Embedding model id.";
      };
      dimension = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = 1536;
        description = "Embedding output dimension (text-embedding-3-small is 1536).";
      };
      maxInputTokens = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = ''
          Estimated-token cap per embedding input (`embedding.max_input_tokens`).
          The server truncates longer text and estimates 4 characters per
          token, which undercounts code. Null sends every input whole.
        '';
      };
      allowMetadataOverride = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          ov.conf `embedding.allow_metadata_override`: adopt an existing
          vector collection whose provider/model metadata differs from the
          current config, as long as the dimension is unchanged. The server
          rewrites the collection metadata and keeps the vectors. Use when
          the same model moved to a new endpoint id; never across genuinely
          different models (vector semantics must match).
        '';
      };
    };
  };

  vlmType = lib.types.submodule {
    options = providerCommon // {
      fallback = fallbackOption vlmFallbackType;
      model = lib.mkOption {
        type = lib.types.str;
        default = "openai/gpt-4o-mini";
        description = "Vision/LLM model id.";
      };
      timeout = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = ''
          Per-request HTTP timeout in seconds (ov.conf `vlm.timeout`). Null
          keeps the server default (600).
        '';
      };
    };
  };

  # Rerank needs the full endpoint URL in api_base, so it gets its own type.
  # No maxConcurrent: extra: forbid would reject it.
  rerankType = lib.types.submodule {
    options = {
      provider = lib.mkOption {
        type = lib.types.str;
        default = "openai";
        description = "Rerank provider (`openai` selects the OpenAI-compatible flat-protocol client).";
      };
      apiBase = lib.mkOption {
        type = lib.types.str;
        description = "Full rerank endpoint URL (the client POSTs to this exact URL).";
      };
      model = lib.mkOption {
        type = lib.types.str;
        description = "Rerank model id.";
      };
      apiKey = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Literal API key. Insecure: prefer apiKeyFile injection.";
      };
      maxInputTokens = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        description = ''
          Estimated-token cap per query+document pair (`max_input_tokens`).
          Null keeps the server default (0, unlimited).
        '';
      };
    };
  };

  # ov.conf without secrets; the runner injects the key from apiKeyFile.
  templateConf = pkgs.writeText "openviking-ov.conf.template" (
    builtins.toJSON (
      ov.mkOvConf {
        workspace = "${cfg.workspace}/.openviking";
        inherit (cfg) logLevel;
        inherit (cfg) embedding vlm;
        inherit (cfg) queryPlanner;
        inherit (cfg) botAgentModel;
        rerank =
          if cfg.rerank == null then
            null
          else
            pruneNull {
              inherit (cfg.rerank) provider model;
              api_base = cfg.rerank.apiBase;
              api_key = cfg.rerank.apiKey;
              max_input_tokens = cfg.rerank.maxInputTokens;
            };
        extra = cfg.settingsExtra;
      }
    )
  );

  # Binary + flags minus --config; the runner appends the resolved config path.
  baseArgs = ov.mkExecArgs { inherit (cfg) package host port; };

  resolveConf =
    if cfg.configFile != null then
      "conf=${lib.escapeShellArg (toString cfg.configFile)}"
    else if cfg.apiKeyFile != null || cfg.fallbackApiKeyFile != null then
      let
        readKey = f: if f == null then ''""'' else ''"$(cat ${lib.escapeShellArg (toString f)})"'';
        primary =
          lib.optionalString (cfg.apiKeyFile != null)
            ''.embedding.dense.api_key = $k | .vlm.api_key = $k | if has("query_planner") then .query_planner.api_key = $k else . end | if has("rerank") then .rerank.api_key = $k else . end | if has("bot") and (.bot.agents.model // "") != "" then .bot.agents.api_key = $k else . end | '';
        # The credentials list replaces the flat fields, so its primary needs
        # the apiKeyFile key too.
        setCredentials =
          path:
          ''if ${path} then ${path} |= map(if .id == "fallback" and $f != "" then .api_key = $f elif .id == "primary" and $k != "" then .api_key = $k else . end) else . end'';
        fallback = "${setCredentials ".embedding.dense.credentials"} | ${setCredentials ".vlm.credentials"}";
      in
      ''
        runtime_dir="''${XDG_RUNTIME_DIR:-$workspace}"
        conf="$runtime_dir/openviking-ov.conf"
        ( umask 077
          ${lib.getExe pkgs.jq} --arg k ${readKey cfg.apiKeyFile} --arg f ${readKey cfg.fallbackApiKeyFile} \
            ${lib.escapeShellArg (primary + fallback)} \
            ${templateConf} > "$conf" )
      ''
    else
      "conf=${templateConf}";

  runner = pkgs.writeShellScript "openviking-server-run" ''
    set -eu
    # Bot mode finds vikingbot via shutil.which; its `python -m vikingbot`
    # fallback fails under wrapped interpreters, so the bin dir must be on PATH.
    export PATH="${cfg.package}/bin:$PATH"
    workspace=${lib.escapeShellArg cfg.workspace}
    mkdir -p "$workspace/.openviking"
    ${resolveConf}
    exec ${lib.escapeShellArgs baseArgs} --config "$conf"
  '';
in
{
  options.programs.openviking-server = (ov.commonServiceOptions { inherit extraPkgs; }) // {
    enable = lib.mkEnableOption "the per-user OpenViking context-filesystem server";

    workspace = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.dataHome}/openviking";
      defaultText = lib.literalExpression ''"''${config.xdg.dataHome}/openviking"'';
      description = ''
        Per-user state directory. The server's workspace is created at
        `<workspace>/.openviking` by the runner at start.
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.str;
      default = "INFO";
      description = "Log level written to the ov.conf `log.level`.";
    };

    embedding = lib.mkOption {
      type = embeddingType;
      default = { };
      description = "Embedding provider configuration (defaults to OpenRouter's OpenAI-compatible endpoint).";
    };

    vlm = lib.mkOption {
      type = vlmType;
      default = { };
      description = "Vision/LLM provider configuration (defaults to OpenRouter's OpenAI-compatible endpoint).";
    };

    queryPlanner = lib.mkOption {
      type = lib.types.nullOr vlmType;
      default = null;
      description = ''
        Retrieval intent / query-planner model (ov.conf `query_planner`).
        Null leaves the section unset so the server falls back to `vlm`.
      '';
    };

    botAgentModel = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Model id for the vikingbot gateway agent (ov.conf `bot.agents.model`).
        Null leaves the section unset so the bot inherits the root `vlm`.
        When set, the bot's provider chain becomes explicit: the runner
        injects the apiKeyFile key into bot.agents.api_key, and provider /
        api_base fall back to the vlm option's values.
      '';
    };

    rerank = lib.mkOption {
      type = lib.types.nullOr rerankType;
      default = null;
      description = ''
        Rerank provider (ov.conf `rerank`). Null leaves the section unset
        (rerank off). Unlike embedding/vlm, apiBase must be the full
        rerank endpoint URL: the server's OpenAI-compatible rerank
        client POSTs to it verbatim.
      '';
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/user/1000/openrouter-key";
      description = ''
        File holding the provider API key, read at service start and injected
        into both the embedding and VLM blocks of the rendered ov.conf. Keeps
        the key out of the Nix store. Ignored when `configFile` is set.
      '';
    };

    fallbackApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/user/1000/openrouter-key";
      description = ''
        File holding the key for `embedding.fallback` / `vlm.fallback`, read
        at service start and injected into those credentials only. Ignored
        when `configFile` is set.
      '';
    };

    afterUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "secrets-provisioner.service" ];
      description = ''
        User units to order the server after (and want), for example one that
        materialises `apiKeyFile` before the runner reads it.
      '';
    };

    settingsExtra = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Extra attributes merged into the generated ov.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = isLinux;
        message = "programs.openviking-server is x86_64-linux only (the upstream server ships a manylinux wheel).";
      }
    ]
    ++
      map
        (role: {
          assertion =
            cfg.${role}.fallback == null
            || cfg.${role}.fallback.apiKey != null
            || cfg.fallbackApiKeyFile != null;
          message = "programs.openviking-server.${role}.fallback needs fallbackApiKeyFile or fallback.apiKey.";
        })
        [
          "embedding"
          "vlm"
        ];

    systemd.user.services.openviking-server = lib.mkIf isLinux {
      Unit = {
        Description = "OpenViking context-filesystem server (user)";
        After = [ "network-online.target" ] ++ cfg.afterUnits;
        Wants = [ "network-online.target" ] ++ cfg.afterUnits;
      };
      Service = {
        # No WorkingDirectory: systemd won't create it and the runner mkdir's
        # the workspace itself; the unit inherits the user's home as cwd.
        ExecStart = toString runner;
        Environment = lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment;
        EnvironmentFile = cfg.environmentFiles;
        Restart = "on-failure";
        RestartSec = "5s";
        # The server re-raises SIGTERM as SystemExit(128 + 15) after its
        # queue drain, so a clean stop exits 143.
        SuccessExitStatus = [ 143 ];
        # 0.5.1 drains in about 5 s; 0.5.0 hung the full 90 s default.
        TimeoutStopSec = "30s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
