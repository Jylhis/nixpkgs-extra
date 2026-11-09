# agentsview, a local web UI over the session files of Claude Code, Codex,
# OpenCode and Hermes. It reads those files and keeps its own SQLite index
# under dataDir; it installs no hooks and never writes to the session roots.
#
# Sandbox: with `sandbox.enable` the units see the whole home read-only
# (ProtectHome) and write only dataDir, so every session root is covered
# without a path list.
#
# Settings: agentsview rewrites dataDir/config.toml itself (auth_token,
# cursor_secret) and reads it only at daemon start, so Nix cannot own the
# file. `settings` lists the top-level tables Nix manages; the
# home-manager activation step replaces exactly those and leaves every other
# key alone, then restarts the service when the file changed.
#
# Gateway: with `llama.enable`, semantic search and Recall extraction go
# through the model gateway of services.llamaServers. Its key is passed as a
# systemd credential, never written to config.toml. Without it the module
# still owns the `vector` and `recall` tables and writes them disabled: the
# merge keeps tables Nix no longer lists, so dropping them would leave the
# jobs of a previous llama.enable running without the key.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.agentsview;
  llamaCfg = config.services.llamaServers;
  home = config.home.homeDirectory;
  tomlFormat = pkgs.formats.toml { };
  sb = cfg.sandbox;

  settingsFile = pkgs.writeText "agentsview-settings.json" (builtins.toJSON cfg.settings);
  confFile = "${cfg.dataDir}/config.toml";
  configMerge = import ./config-merge.nix { inherit pkgs; };

  agentsview = lib.getExe cfg.package;

  sandbox = lib.optionalAttrs sb.enable {
    ProtectSystem = "strict";
    ProtectHome = "read-only";
    ReadWritePaths = [ cfg.dataDir ];
    ProtectKernelTunables = true;
    ProtectControlGroups = true;
    RestrictNamespaces = true;
    LockPersonality = true;
    RestrictRealtime = true;
    SystemCallArchitectures = "native";
  };

  lowPriority = lib.optionalAttrs cfg.lowPriority {
    Nice = 10;
    IOSchedulingClass = "idle";
    CPUWeight = 20;
  };

  hardening = {
    PrivateTmp = true;
    NoNewPrivileges = true;
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
  };

  environment = [
    "AGENTSVIEW_DATA_DIR=${cfg.dataDir}"
    "AGENTSVIEW_DISABLE_UPDATE_CHECK=1"
    # The PostHog reporter defaults to on; these opt out.
    "AGENTSVIEW_TELEMETRY_ENABLED=0"
    "DO_NOT_TRACK=1"
  ]
  # ProtectHome leaves ~/.cache read-only; agentsview caches under XDG.
  ++ lib.optional sb.enable "XDG_CACHE_HOME=${cfg.dataDir}/cache"
  ++ lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment;

  serveArgs = "serve --host 127.0.0.1 --port ${toString cfg.port} --no-browser${
    lib.optionalString (
      cfg.publicOrigins != [ ]
    ) " --public-origin ${lib.escapeShellArg (lib.concatStringsSep "," cfg.publicOrigins)}"
  }";

  # The credential directory only exists inside the unit, so the key is read
  # at start and exported for the api_key_env settings below.
  serveWrapper = pkgs.writeShellScript "agentsview-serve" ''
    AGENTSVIEW_GATEWAY_KEY=$(<"$CREDENTIALS_DIRECTORY/gateway-key")
    export AGENTSVIEW_GATEWAY_KEY
    exec ${agentsview} ${serveArgs}
  '';

  # sops-nix renders the gateway key that LoadCredential reads.
  sopsUnit = lib.optional (config.systemd.user.services ? sops-nix) "sops-nix.service";
  gatewayUnit = lib.optionalAttrs cfg.llama.enable {
    After = [ llamaCfg.gatewayService ] ++ sopsUnit;
    Wants = [ llamaCfg.gatewayService ] ++ sopsUnit;
  };

  # Both commands talk to the running daemon (loopback, token from config.toml).
  maintenanceService = description: args: {
    Unit = {
      Description = description;
      After = [ "agentsview.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${agentsview} ${args}";
      Environment = environment;
    }
    // hardening
    // sandbox
    // lowPriority;
  };

  maintenanceTimer = description: onCalendar: {
    Unit.Description = description;
    Timer = {
      OnCalendar = onCalendar;
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # agentsview fingerprints the embedding model, dimension, prefix and input
  # limits (a change re-embeds every session) and the extraction model and
  # window size (a change re-extracts them). mkDefault on the leaves lets a
  # host override one without restating the table.
  d = lib.mkDefault;
  llamaSettings = {
    vector = {
      enabled = d true;
      embeddings = {
        model = d cfg.llama.embeddingModel;
        dimension = d cfg.llama.dimension;
        max_input_chars = d 5000;
        model_context_tokens = d 4096;
        default_server = d "gateway";
        servers.gateway = {
          endpoint = d cfg.llama.endpoint;
          api_key_env = d "AGENTSVIEW_GATEWAY_KEY";
          batch_size = d 2;
          concurrency = d 1;
          timeout = d "110s";
          max_retries = d 3;
        };
      }
      // lib.optionalAttrs (cfg.llama.queryPrefix != null) { query_prefix = d cfg.llama.queryPrefix; };
      embed = {
        run_after_sync = d true;
        recall = d true;
        backstop_interval = d "24h";
      };
    };
    recall.extract = {
      enabled = d true;
      model = d cfg.llama.extractModel;
      server = d "gateway";
      max_window_chars = d 24000;
      quiet_period = d "30m";
      backstop_interval = d "1h";
      failure_backoff = d "6h";
      candidate_findings = d "block";
      servers.gateway = {
        endpoint = d cfg.llama.endpoint;
        api_key_env = d "AGENTSVIEW_GATEWAY_KEY";
        timeout = d "110s";
        concurrency = d 2;
      };
    };
  };

  # Turning llama.enable off must reach config.toml: these replace the tables
  # above, so the model servers go too.
  llamaOffSettings = {
    vector.enabled = d false;
    recall.extract.enabled = d false;
  };
in
{
  options.services.agentsview = {
    enable = lib.mkEnableOption "the agentsview session browser as a user service";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.llm-agents.agentsview or null;
      defaultText = lib.literalExpression "pkgs.llm-agents.agentsview";
      description = ''
        The agentsview package. Comes from numtide/llm-agents.nix: apply its
        `overlays.shared-nixpkgs` or set this option.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8086;
      description = "Loopback port of the web UI.";
    };

    publicOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "http://agentsview.localhost" ];
      description = ''
        Extra origins that pass the Host and Origin checks (`--public-origin`),
        for a reverse proxy in front of the UI.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${home}/.agentsview";
      defaultText = lib.literalExpression ''"''${config.home.homeDirectory}/.agentsview"'';
      description = "Directory of the SQLite index and config.toml; agentsview creates it.";
    };

    readOnlyPaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "${home}/.claude"
        "${home}/.codex"
        "${home}/.local/share/opencode"
        "${home}/.hermes"
      ];
      defaultText = lib.literalExpression ''
        map (p: "''${config.home.homeDirectory}/" + p) [
          ".claude"
          ".codex"
          ".local/share/opencode"
          ".hermes"
        ]
      '';
      description = ''
        Session roots the unit sees read-only. With `sandbox.enable` the whole
        home is read-only already; list roots outside the home here.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        HTTP_PROXY = "http://127.0.0.1:9";
      };
      description = ''
        Extra environment of the service and the maintenance units. A dead
        proxy here keeps agentsview offline if a firewall rule fails (Go
        never proxies loopback, so the UI and the gateway still work).
      '';
    };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      description = ''
        Top-level tables Nix owns in config.toml. Each listed table is
        replaced wholesale at activation; everything else (auth_token,
        cursor_secret) stays agentsview's. The daemon reads the file only at
        start, so a change restarts the service. `vector` and `recall` are
        always owned: `llama.enable` fills them, and without it they are
        written disabled.
      '';
    };

    sandbox.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Mount the home read-only and the system strict, with dataDir the only
        writable path, and set the other systemd sandbox options. Turn it off
        if a session root needs write access or the sandbox does not start
        in your setup.
      '';
    };

    lowPriority = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run the units at Nice 10, idle I/O class and CPUWeight 20: indexing must not compete with the desktop.";
    };

    memoryHigh = lib.mkOption {
      type = lib.types.str;
      default = "2G";
      description = "MemoryHigh of the service (throttling starts here).";
    };

    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "4G";
      description = "MemoryMax of the service (the OOM limit).";
    };

    llama = {
      enable = lib.mkEnableOption "semantic search and Recall extraction through the model gateway of `services.llamaServers`";

      endpoint = lib.mkOption {
        type = lib.types.str;
        default = llamaCfg.gatewayURL;
        defaultText = lib.literalExpression "config.services.llamaServers.gatewayURL";
        description = "OpenAI-compatible base URL of the gateway.";
      };

      apiKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = llamaCfg.masterKeyFile;
        defaultText = lib.literalExpression "config.services.llamaServers.masterKeyFile";
        description = "File holding the gateway bearer key, passed to the unit as a credential.";
      };

      embeddingModel = lib.mkOption {
        type = lib.types.str;
        example = "qwen3-emb-8b";
        description = "Gateway model name used for embeddings (a key of `services.llamaServers.models`).";
      };

      dimension = lib.mkOption {
        type = lib.types.ints.positive;
        example = 4096;
        description = "Vector dimension of the embedding model.";
      };

      queryPrefix = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "Instruct: Given a search query, retrieve relevant passages from coding agent session transcripts\nQuery:";
        description = ''
          Prefix agentsview puts before search queries, for instruction-tuned
          embedding models. Null sends the query as is.
        '';
      };

      extractModel = lib.mkOption {
        type = lib.types.str;
        example = "claude-haiku";
        description = ''
          Gateway model name used for Recall extraction: a key of
          `services.llamaServers.models` or `anthropicModels`. A large local
          model on the CPU can hold many GB for days of backlog, so a cloud
          model is often the better choice.
        '';
      };
    };

    maintenance = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Run the periodic secrets scan and database compaction.";
      };

      secretsScan.onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "daily";
        description = ''
          Schedule of `agentsview secrets scan --backfill`. Recall extraction
          only takes sessions with a full secret scan.
        '';
      };

      compact.onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "weekly";
        description = "Schedule of `agentsview db compact --yes`.";
      };
    };

    configMerge = lib.mkOption {
      type = lib.types.package;
      internal = true;
      readOnly = true;
      default = configMerge;
      description = "Script that merges `settings` into config.toml (exposed for tests).";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = cfg.package != null;
            message = "services.agentsview.package is unset: apply the overlays.shared-nixpkgs overlay of numtide/llm-agents.nix (it provides pkgs.llm-agents.agentsview) or set the option.";
          }
        ];
      }
      (lib.mkIf cfg.llama.enable {
        assertions = [
          {
            assertion = llamaCfg.enable;
            message = "services.agentsview.llama: services.llamaServers must be enabled.";
          }
          {
            assertion =
              llamaCfg.models ? ${cfg.llama.embeddingModel}
              && (
                llamaCfg.models ? ${cfg.llama.extractModel} || llamaCfg.anthropicModels ? ${cfg.llama.extractModel}
              );
            message = "services.agentsview.llama: embeddingModel must be in services.llamaServers.models, extractModel in models or anthropicModels.";
          }
          {
            assertion = cfg.llama.apiKeyFile != null;
            message = "services.agentsview.llama: apiKeyFile is required (the gateway rejects keyless requests).";
          }
        ];
      })
      (lib.mkIf (cfg.package != null) {
        services.agentsview.settings = if cfg.llama.enable then llamaSettings else llamaOffSettings;

        home.packages = [ cfg.package ];

        home.activation = {
          # ReadWritePaths needs the directory before the first start, settings
          # or not, or the unit fails to set up its namespace.
          agentsviewDataDir = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "writeBoundary" ] ''
            run mkdir -m 700 -p ${lib.escapeShellArg cfg.dataDir}
          '';

          # The script honours DRY_RUN itself, hence no `run`. It also repairs a
          # managed table edited by hand, which leaves the unit unchanged, so the
          # restart keys on the file changing rather than on the settings path.
          agentsviewConfig = lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "agentsviewDataDir" ] ''
            # A config.toml it cannot parse (a hand edit) warns instead of
            # failing: the rest of the activation must still go through.
            agentsviewConfigChanged=
            if agentsviewMerge=$(DRY_RUN="''${DRY_RUN:-}" ${lib.getExe cfg.configMerge} ${lib.escapeShellArg confFile} ${settingsFile}); then
              if [ "$agentsviewMerge" = changed ]; then
                agentsviewConfigChanged=1
              fi
            else
              warnEcho "agentsview: ${confFile} not merged (invalid TOML?); fix it and switch again"
            fi
          '';

          agentsviewRestart = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
            if [ -n "''${agentsviewConfigChanged:-}" ]; then
              run ${config.systemd.user.systemctlPath} --user try-restart agentsview.service \
                || warnEcho "agentsview: restart after the config merge failed"
            fi
          '';
        };

        systemd.user.services = {
          agentsview = {
            # A settings change restarts the daemon through agentsviewRestart.
            Unit = {
              Description = "agentsview session browser";
            }
            // gatewayUnit;
            Service = {
              ExecStart = if cfg.llama.enable then toString serveWrapper else "${agentsview} ${serveArgs}";
              Environment = environment;
              MemoryHigh = cfg.memoryHigh;
              MemoryMax = cfg.memoryMax;
              # Missing roots (a tool never used) must not fail the unit, hence the "-".
              ReadOnlyPaths = map (p: "-${p}") cfg.readOnlyPaths;
              Restart = "on-failure";
              RestartSec = "5s";
            }
            // hardening
            // sandbox
            // lowPriority
            // lib.optionalAttrs cfg.llama.enable {
              LoadCredential = [ "gateway-key:${toString cfg.llama.apiKeyFile}" ];
            };
            Install.WantedBy = [ "default.target" ];
          };

          agentsview-secrets-scan = lib.mkIf cfg.maintenance.enable (
            maintenanceService "agentsview secrets scan" "secrets scan --backfill"
          );
          agentsview-compact = lib.mkIf cfg.maintenance.enable (
            maintenanceService "agentsview database compaction" "db compact --yes"
          );
        };

        systemd.user.timers = lib.mkIf cfg.maintenance.enable {
          agentsview-secrets-scan = maintenanceTimer "agentsview secrets scan" cfg.maintenance.secretsScan.onCalendar;
          agentsview-compact = maintenanceTimer "agentsview database compaction" cfg.maintenance.compact.onCalendar;
        };
      })
    ]
  );
}
