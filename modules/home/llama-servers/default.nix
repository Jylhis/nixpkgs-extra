# A per-user local model stack: llama-swap in front of one llama-server per
# catalog entry, with the Bifrost gateway in front of llama-swap.
#
#   clients -> bifrost (gatewayURL, virtual key) -> llama-swap (swapPort)
#                                               \-> OpenRouter (optional)
#
# Both daemons run as systemd user units (nixpkgs' services.llama-swap is a
# system service), with the llama-swap config built from a typed catalog.
# Models are `resident` (never evicted, warmed after start) or `chat`
# (swapped on demand).
#
# Secrets are read from files at start into a 0600 env file under
# $XDG_RUNTIME_DIR; none enters the store.
{
  config,
  lib,
  pkgs,
  extraPkgs,
  ...
}:
let
  cfg = config.services.llamaServers;
  bifrostLib = import ./bifrost-config.nix { inherit lib; };

  llamaServer = lib.getExe' cfg.llamaCppPackage "llama-server";

  # A store path (a fetched GGUF) or a runtime path string.
  weightsType = lib.types.nullOr (lib.types.either lib.types.package lib.types.str);

  modelType = lib.types.submodule (
    { config, ... }:
    {
      options = {
        kind = lib.mkOption {
          type = lib.types.enum [
            "chat"
            "embedding"
            "reranker"
          ];
          default = "chat";
          description = ''
            Server mode: `embedding` adds `--embeddings`, `reranker` adds
            `--reranking --pooling rank`. Also picks the default group and
            the route the warmup request uses.
          '';
        };

        model = lib.mkOption {
          type = weightsType;
          default = null;
          example = lib.literalExpression ''
            pkgs.fetchurl {
              url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
              hash = "sha256-...";
            }
          '';
          description = ''
            GGUF weights, passed as `-m`: a fetched store path or a path
            outside the store (large weights are often kept in a cache
            directory). Null leaves `-m` to `extraArgs`.
          '';
        };

        mmproj = lib.mkOption {
          type = weightsType;
          default = null;
          description = "Vision projector GGUF (`--mmproj`).";
        };

        devices = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "Vulkan1" ];
          description = ''
            Devices this model runs on (`-dev`), in llama.cpp's naming
            (`llama-server --list-devices`). Empty leaves llama.cpp's
            default. Vulkan numbers devices in enumeration order, which can
            differ from DRM card numbering.
          '';
        };

        gpuLayers = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          default = null;
          example = 99;
          description = "Layers offloaded to the GPU (`-ngl`); 0 keeps the model on the CPU. Null keeps llama.cpp's default.";
        };

        nCpuMoe = lib.mkOption {
          type = lib.types.nullOr lib.types.ints.unsigned;
          default = null;
          description = "Layers whose MoE expert weights stay in system RAM (`--n-cpu-moe`).";
        };

        extraArgs = lib.mkOption {
          type = lib.types.separatedString " ";
          default = "";
          example = "-c 8192 -fa on -ctk q8_0 -ctv q8_0";
          description = "Extra llama-server arguments after the generated ones.";
        };

        ttl = lib.mkOption {
          type = lib.types.ints.u16;
          default = 0;
          description = "Unload after this many idle seconds (0 = never).";
        };

        group = lib.mkOption {
          type = lib.types.enum [
            "resident"
            "chat"
          ];
          default = if config.kind == "chat" then "chat" else "resident";
          defaultText = lib.literalExpression ''if kind == "chat" then "chat" else "resident"'';
          description = ''
            `resident`: loaded at start, never evicted. `chat`: loaded on
            demand, one at a time, swapped out by the next chat request.
          '';
        };

        oomScoreAdjust = lib.mkOption {
          type = lib.types.nullOr (lib.types.ints.between 0 1000);
          default = null;
          description = ''
            oom_score_adj for this model's llama-server, set with choom.
            Null inherits the unit's
            {option}`services.llamaServers.resourceControl.oomScoreAdjust`.
            Only raising it works: the user manager cannot lower a score.
          '';
        };
      };
    }
  );

  serverArgs =
    m:
    lib.concatStringsSep " " (
      lib.optional (m.kind == "embedding") "--embeddings"
      ++ lib.optionals (m.kind == "reranker") [
        "--reranking"
        "--pooling rank"
      ]
      ++ lib.optional (m.model != null) "-m ${lib.escapeShellArg "${m.model}"}"
      ++ lib.optional (m.mmproj != null) "--mmproj ${lib.escapeShellArg "${m.mmproj}"}"
      ++ lib.optional (m.devices != [ ]) "-dev ${lib.concatStringsSep "," m.devices}"
      ++ lib.optional (m.gpuLayers != null) "-ngl ${toString m.gpuLayers}"
      ++ lib.optional (m.nCpuMoe != null) "--n-cpu-moe ${toString m.nCpuMoe}"
      ++ lib.optional (m.extraArgs != "") m.extraArgs
    );

  # Warm a resident through the route its kind serves.
  warmup =
    name: m:
    let
      route =
        {
          reranker = "rerank";
          embedding = "embeddings";
          chat = "chat/completions";
        }
        .${m.kind};
      body =
        {
          reranker = {
            model = name;
            query = "warmup";
            documents = [ "warmup" ];
          };
          embedding = {
            model = name;
            input = "warmup";
          };
          chat = {
            model = name;
            messages = [
              {
                role = "user";
                content = "warmup";
              }
            ];
            max_tokens = 1;
          };
        }
        .${m.kind};
    in
    pkgs.writeShellScript "llama-swap-warm-${name}" ''
      base=http://127.0.0.1:${toString cfg.swapPort}/v1
      curl=${lib.getExe pkgs.curl}
      for _ in 1 2 3 4 5 6 7 8 9 10; do
        "$curl" -sf -m 600 "$base/models" >/dev/null && break
        sleep 2
      done
      "$curl" -sf -m 600 -X POST "$base/${route}" -H 'Content-Type: application/json' \
        -d ${lib.escapeShellArg (builtins.toJSON body)} >/dev/null || true
    '';

  residentModels = lib.filterAttrs (_: m: m.group == "resident") cfg.models;
  chatModels = lib.filterAttrs (_: m: m.group == "chat") cfg.models;

  # Residents coexist with the chat model without eviction. They are warmed
  # by llama-swap-warmup because on_startup.preload did not fire for grouped
  # models.
  swapSettings = {
    routing.router = {
      use = "group";
      settings.groups = {
        resident = {
          persistent = true;
          swap = false;
          exclusive = false;
          members = lib.attrNames residentModels;
        };
        chat = {
          swap = true;
          exclusive = false;
          members = lib.attrNames chatModels;
        };
      };
    };
    models = lib.mapAttrs (_: m: {
      cmd = lib.concatStringsSep " " (
        lib.optionals (m.oomScoreAdjust != null) [
          (lib.getExe' pkgs.util-linux "choom")
          "-n"
          (toString m.oomScoreAdjust)
          "--"
        ]
        ++ [ "${llamaServer} --port \${PORT} --host 127.0.0.1 ${serverArgs m}" ]
      );
      # The servers bind 127.0.0.1; llama-swap's default `localhost` target
      # tries [::1] first.
      proxy = "http://127.0.0.1:\${PORT}";
      inherit (m) ttl;
    }) cfg.models;
  };

  swapConfigUnvalidated = pkgs.writers.writeYAML "llama-swap.yml" cfg.swapSettings;
  # The same check nixpkgs' services.llama-swap runs on its config.
  swapConfig =
    if cfg.validateConfig then
      pkgs.runCommandLocal "llama-swap-validated.yml"
        {
          nativeBuildInputs = [ cfg.llamaSwapPackage ];
        }
        ''
          llama-swap -validate -config ${swapConfigUnvalidated}
          cp ${swapConfigUnvalidated} $out
        ''
    else
      swapConfigUnvalidated;

  needsOpenrouter = cfg.cloudModels != { } || cfg.openrouterFallbacks != { };

  # Quoted for sourcing: values may hold spaces ("Bearer ...").
  quotedLine = var: file: ''
    if [ -r ${lib.escapeShellArg file} ]; then
      printf '${var}=%q\n' "$(cat ${lib.escapeShellArg file})"
    fi
  '';

  otelEnvVar = n: "BIFROST_OTEL_" + lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] n);
  bearerVar = "BIFROST_OTEL_BEARER";
  otelSettings =
    if cfg.otel.enable then
      {
        inherit (cfg.otel) endpoint traceType;
        headers =
          lib.mapAttrs (n: _: otelEnvVar n) cfg.otel.headerFiles
          // lib.optionalAttrs (cfg.otel.bearerKeyFile != null) { authorization = bearerVar; };
      }
    else
      null;

  # config.json is rendered from the catalog and copied into the state dir on
  # every start. The config store (SQLite, ./config.db there) is required:
  # without it Bifrost skips governance and serves keyless.
  bifrostSettings = bifrostLib.render {
    inherit (cfg)
      swapPort
      cloudModels
      anthropicModels
      timeouts
      openrouterFallbacks
      overflow
      extraFallbacks
      mcpServers
      datasheetDir
      disableMcpAutoToolInject
      ;
    localModels = cfg.models;
    otel = otelSettings;
    timeout = cfg.requestTimeout;
  };
  bifrostConfig = pkgs.writers.writeJSON "bifrost-config.json" cfg.bifrostSettings;

  bifrostRunner = pkgs.writeShellScript "bifrost-run" ''
    set -eu
    runtime_dir="''${XDG_RUNTIME_DIR:-/tmp}"
    env_file="$runtime_dir/bifrost-$USER.env"
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/bifrost"
    mkdir -p "$state"
    vk="$(cat ${lib.escapeShellArg (toString cfg.masterKeyFile)})"
    case "$vk" in
      sk-bf-*) ;;
      *) echo "bifrost: the virtual key must start with sk-bf-" >&2; exit 1 ;;
    esac
    (
      umask 077
      # The dashboard password is made once per user, never in the store.
      if [ ! -s "$state/admin-password" ]; then
        head -c 24 /dev/urandom | base64 | tr -d '/+=\n' > "$state/admin-password"
      fi
      {
    ${lib.optionalString (cfg.openrouterApiKeyFile != null) ''
      printf 'OPENROUTER_API_KEY=%q\n' "$(cat ${lib.escapeShellArg (toString cfg.openrouterApiKeyFile)})"
    ''}
    ${lib.optionalString (cfg.anthropicApiKeyFile != null) (
      quotedLine "ANTHROPIC_API_KEY" (toString cfg.anthropicApiKeyFile)
    )}
        printf 'BIFROST_VK=%q\n' "$vk"
        printf 'BIFROST_ADMIN_USERNAME=admin\n'
        printf 'BIFROST_ADMIN_PASSWORD=%q\n' "$(cat "$state/admin-password")"
    ${lib.concatStrings (
      lib.mapAttrsToList (_: s: ''
        if [ -r ${lib.escapeShellArg (toString s.keyFile)} ]; then
          printf '${s.envVar}=%q\n' "${bifrostLib.headerValue s "$(cat ${lib.escapeShellArg (toString s.keyFile)})"}"
        fi
      '') cfg.mcpServers
    )}
    ${lib.concatStrings (
      lib.mapAttrsToList (n: file: quotedLine (otelEnvVar n) (toString file)) cfg.otel.headerFiles
    )}
    ${lib.optionalString (cfg.otel.bearerKeyFile != null) ''
      printf '${bearerVar}=%q\n' "Bearer $(cat ${lib.escapeShellArg (toString cfg.otel.bearerKeyFile)})"
    ''}
    ${lib.optionalString cfg.otel.enable ''
      printf 'OTEL_RESOURCE_ATTRIBUTES=%q\n' "openinference.project.name=${cfg.otel.project}"
    ''}
      } > "$env_file"
    )
    set -a
    . "$env_file"
    set +a
    install -m 0600 ${bifrostConfig} "$state/config.json"
    cd "$state"
    exec ${lib.getExe cfg.bifrostPackage} -app-dir "$state" -host 127.0.0.1 -port ${toString cfg.bifrostPort} -log-level warn
  '';

  rc = cfg.resourceControl;
  grc = cfg.gatewayResourceControl;
in
{
  options.services.llamaServers = {
    enable = lib.mkEnableOption "the per-user local model stack (llama-swap behind the Bifrost gateway)";

    llamaCppPackage = lib.mkPackageOption pkgs "llama-cpp" {
      example = "llama-cpp-vulkan";
      extraDescription = "Pick the build for the GPU backend (Vulkan, ROCm, CUDA) the models run on.";
    };

    llamaSwapPackage = lib.mkPackageOption pkgs "llama-swap" { };

    bifrostPackage = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.bifrost;
      defaultText = lib.literalExpression "pkgs.bifrost";
      description = "The Bifrost gateway package.";
    };

    models = lib.mkOption {
      type = lib.types.attrsOf modelType;
      default = { };
      example = lib.literalExpression ''
        {
          small-chat = {
            model = "/var/cache/models/small-chat-Q4_K_M.gguf";
            gpuLayers = 0;
            extraArgs = "-t 8 -c 16384";
            ttl = 1800;
          };
          embedder = {
            kind = "embedding";
            model = pkgs.fetchurl { url = "..."; hash = "..."; };
            devices = [ "Vulkan0" ];
            gpuLayers = 99;
            extraArgs = "--pooling last -c 4096";
          };
        }
      '';
      description = ''
        llama-swap model catalog: the name clients send -> one llama-server.
        At least one model must be resident.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        GGML_VK_VISIBLE_DEVICES = "0,1";
      };
      description = ''
        Environment of the llama-swap unit, inherited by every llama-server:
        backend device selection (`GGML_VK_VISIBLE_DEVICES`,
        `HIP_VISIBLE_DEVICES`, `CUDA_VISIBLE_DEVICES`) and the like.
      '';
    };

    validateConfig =
      lib.mkEnableOption "checking the generated llama-swap config with `llama-swap -validate` at build time"
      // {
        default = true;
      };

    swapPort = lib.mkOption {
      type = lib.types.port;
      default = 8710;
      description = "Loopback port of llama-swap.";
    };

    bifrostPort = lib.mkOption {
      type = lib.types.port;
      default = 4080;
      description = "Loopback port of the Bifrost gateway (its own default, 8080, is often taken).";
    };

    requestTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 120;
      description = "Seconds Bifrost waits on a provider, except for models with an `overflow` timeout.";
    };

    datasheetDir = lib.mkOption {
      type = lib.types.nullOr (lib.types.either lib.types.path lib.types.str);
      default = "${cfg.bifrostPackage.src}/examples/configs/withlocalpricingfiles";
      defaultText = lib.literalExpression ''"''${bifrostPackage.src}/examples/configs/withlocalpricingfiles"'';
      description = ''
        Directory holding Bifrost's `pricing.json` and
        `model-parameters.json`. The default is the sample shipped in the
        Bifrost source, so the gateway never fetches them from
        getbifrost.ai. Null lets Bifrost sync them from the web.
      '';
    };

    swapSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      default = swapSettings;
      defaultText = lib.literalMD "generated from `models`";
      description = "The generated llama-swap configuration, for inspection.";
    };

    bifrostSettings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      readOnly = true;
      default = bifrostSettings;
      defaultText = lib.literalMD "generated from the catalog options";
      description = "The generated Bifrost `config.json`, for inspection. Secrets appear only as `env.VAR` references.";
    };

    gatewayPort = lib.mkOption {
      type = lib.types.port;
      readOnly = true;
      default = cfg.bifrostPort;
      defaultText = lib.literalExpression "bifrostPort";
      description = "Loopback port of the model gateway.";
    };

    gatewayURL = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://127.0.0.1:${toString cfg.gatewayPort}/v1";
      defaultText = lib.literalExpression ''"http://127.0.0.1:''${toString gatewayPort}/v1"'';
      description = "OpenAI-compatible base URL of the model gateway. Clients take it from here.";
    };

    gatewayService = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "bifrost.service";
      description = "systemd user unit of the model gateway, for `After=` and `Wants=`.";
    };

    masterKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/user/1000/secrets/bifrost-key";
      description = ''
        File whose whole content is the gateway key. It is the Bifrost
        virtual key and must start with `sk-bf-`: Bifrost requires it on
        inference and MCP routes. Loopback-only is not an auth model: any
        local process could otherwise spend the cloud key.
      '';
    };

    openrouterApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File whose whole content is the OpenRouter API key. Required when
        `cloudModels` or `openrouterFallbacks` is set; without either, the
        gateway serves the local catalog only.
      '';
    };

    openrouterFallbacks = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "small-chat" = "vendor/some-chat-model";
      };
      description = ''
        Local model name -> OpenRouter model id. When the local model fails,
        Bifrost retries the request against that OpenRouter model. Only pair
        models whose outputs are interchangeable: an embedding fallback must
        keep the same dimension.
      '';
    };

    timeouts = lib.mkOption {
      type = lib.types.attrsOf lib.types.ints.positive;
      default = { };
      example = {
        "big-chat" = 900;
      };
      description = ''
        Request timeout in seconds for slow local models without an
        OpenRouter fallback (`overflow.<name>.timeout` covers the others and
        wins). Bifrost gives each distinct timeout its own local provider.
      '';
    };

    overflow = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            rpm = lib.mkOption {
              type = lib.types.ints.positive;
              description = ''
                Requests per minute the local model takes before Bifrost
                sends the rest to its OpenRouter fallback. A count of started
                requests in a 60 s window, not of requests in flight: size it
                to the local model's measured throughput.
              '';
            };
            timeout = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              default = null;
              description = ''
                Seconds before Bifrost stops waiting on the local model and
                fails over. Null keeps `requestTimeout`.
              '';
            };
          };
        }
      );
      default = { };
      example = {
        embedder = {
          rpm = 30;
          timeout = 60;
        };
      };
      description = ''
        Local-first load overflow. Each key must also be in
        `openrouterFallbacks`. Clients keep the local model name, and Bifrost
        uses the OpenRouter model only while the local one is over its cap.
      '';
    };

    extraFallbacks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = {
        "big-vision" = [ "other-vision" ];
      };
      description = ''
        Extra fallback chains beyond `openrouterFallbacks`: model name ->
        fallback model names. Targets must be in `models` or `cloudModels`.
        Use this for cloud-to-cloud fallbacks.
      '';
    };

    cloudModels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "big-vision" = "vendor/some-vision-model";
      };
      description = ''
        Cloud-only models: name clients send -> OpenRouter model id, with no
        local server. `extraFallbacks` may name them.
      '';
    };

    anthropicModels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "claude-haiku" = "claude-haiku-4-5";
      };
      description = ''
        Models served by the direct Anthropic API: name clients send ->
        Anthropic model id. Clients still speak OpenAI-compatible to the
        gateway and Bifrost translates. Needs `anthropicApiKeyFile`. Name a
        `cloudModels` twin in `extraFallbacks` to keep the model reachable
        when Anthropic fails or the credit runs out.
      '';
    };

    anthropicApiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "File whose whole content is the Anthropic API key. Required when `anthropicModels` is set.";
    };

    disableMcpAutoToolInject = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Stop Bifrost from adding the tools of `mcpServers` to every inference
        request. Set it when coding agents also use the gateway as an MCP
        upstream, so each tool appears once.
      '';
    };

    otel = {
      enable = lib.mkEnableOption "OpenTelemetry trace export from Bifrost (its otel plugin)";

      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "http://127.0.0.1:6006/v1/traces";
        description = "OTLP HTTP traces endpoint of the collector.";
      };

      traceType = lib.mkOption {
        type = lib.types.enum [
          "genai_extension"
          "open_inference"
          "vercel"
        ];
        default = "open_inference";
        description = ''
          Span attribute convention. `open_inference` suits Phoenix: it
          renders the LLM span with model and token counts.
        '';
      };

      project = lib.mkOption {
        type = lib.types.str;
        default = "bifrost";
        description = ''
          Project that receives the gateway spans, exported as the
          `openinference.project.name` resource attribute.
        '';
      };

      bearerKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          File holding an API key, sent as the
          `authorization: Bearer <key>` header (what Phoenix expects).
        '';
      };

      headerFiles = lib.mkOption {
        type = lib.types.attrsOf lib.types.path;
        default = { };
        example = {
          x-api-key = "/run/secrets/collector-key";
        };
        description = ''
          Header name -> file whose whole content is the header value. Each
          is passed through an env reference, so the value never enters the
          store or the config database.
        '';
      };
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            url = lib.mkOption {
              type = lib.types.str;
              description = "Upstream MCP server URL the gateway fronts.";
            };
            authType = lib.mkOption {
              type = lib.types.enum [
                "bearer_token"
                "api_key"
              ];
              default = "bearer_token";
              description = ''
                How the upstream takes its key: `bearer_token` sends
                `Authorization: Bearer <key>`, `api_key` sends `x-api-key`.
              '';
            };
            envVar = lib.mkOption {
              type = lib.types.str;
              description = ''
                Environment variable the gateway reads the upstream credential
                from. The runner fills it from `keyFile` at start.
              '';
            };
            keyFile = lib.mkOption {
              type = lib.types.path;
              description = "File whose whole content is the upstream key.";
            };
          };
        }
      );
      default = { };
      description = ''
        MCP servers Bifrost fronts. Each is re-exposed through the gateway
        and authenticated to clients by the gateway key.
      '';
    };

    resourceControl = {
      cpuWeight = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 10000);
        default = null;
        example = 50;
        description = "CPUWeight of llama-swap and its llama-server children. Null keeps systemd's default.";
      };

      memoryHigh = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "60%";
        description = ''
          Soft memory ceiling (systemd MemoryHigh) of llama-swap and its
          children: past it the kernel reclaims this cgroup first. A soft
          ceiling suits mmap'd weights better than MemoryMax.
        '';
      };

      allowedCPUs = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        example = [ "8-15" ];
        description = "cpuset pinning (AllowedCPUs) of llama-swap and its children; null pins nothing.";
      };

      memoryMax = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "75%";
        description = ''
          Hard memory ceiling (systemd MemoryMax) of llama-swap and its
          children. Set it above `memoryHigh` so mmap'd weights still get
          soft reclaim first; past it the kernel OOM-kills inside this
          cgroup instead of squeezing the session.
        '';
      };

      oomPolicy = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.enum [
            "continue"
            "stop"
            "kill"
          ]
        );
        default = null;
        example = "continue";
        description = ''
          systemd OOMPolicy of llama-swap. `continue` keeps llama-swap and
          the other model servers running when the kernel kills one server.
        '';
      };

      oomScoreAdjust = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 0 1000);
        default = null;
        example = 300;
        description = ''
          OOM badness of llama-swap and its llama-server children. A
          positive value makes the model servers the preferred victims of
          the kernel OOM killer (and earlyoom); llama-swap restarts a
          server on the next request.
        '';
      };
    };

    gatewayResourceControl = {
      cpuWeight = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 10000);
        default = null;
        example = 80;
        description = "CPUWeight of the Bifrost gateway unit. Null keeps systemd's default.";
      };

      memoryHigh = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "1G";
        description = "Soft memory ceiling (systemd MemoryHigh) of the Bifrost gateway unit.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "services.llamaServers runs systemd user units and needs Linux.";
      }
      {
        assertion = residentModels != { };
        message = "services.llamaServers.models: at least one model must be resident.";
      }
      {
        assertion = cfg.masterKeyFile != null;
        message = "services.llamaServers.masterKeyFile is required: without a gateway key every local process can use the gateway.";
      }
      {
        assertion = needsOpenrouter -> cfg.openrouterApiKeyFile != null;
        message = "services.llamaServers: cloudModels and openrouterFallbacks need openrouterApiKeyFile.";
      }
      {
        assertion = lib.all (n: cfg.openrouterFallbacks ? ${n} && cfg.models ? ${n}) (
          lib.attrNames cfg.overflow
        );
        message = "services.llamaServers.overflow: every key must be a local model with an openrouterFallbacks entry.";
      }
      {
        assertion = lib.all (n: !(cfg.models ? ${n})) (lib.attrNames cfg.cloudModels);
        message = "services.llamaServers.cloudModels: a name must not also be a local model.";
      }
      {
        assertion = lib.all (n: !(cfg.models ? ${n} || cfg.cloudModels ? ${n})) (
          lib.attrNames cfg.anthropicModels
        );
        message = "services.llamaServers.anthropicModels: a name must not also be a local or cloud model.";
      }
      {
        assertion = cfg.anthropicModels == { } || cfg.anthropicApiKeyFile != null;
        message = "services.llamaServers.anthropicModels needs anthropicApiKeyFile.";
      }
      {
        assertion = lib.all (n: cfg.models ? ${n}) (lib.attrNames cfg.timeouts);
        message = "services.llamaServers.timeouts: every key must be a local model.";
      }
      {
        assertion = lib.all (n: !(cfg.overflow ? ${n})) (lib.attrNames cfg.timeouts);
        message = "services.llamaServers.timeouts: a model in overflow takes overflow.<name>.timeout instead.";
      }
      {
        assertion = lib.all (n: cfg.models ? ${n} || cfg.cloudModels ? ${n} || cfg.anthropicModels ? ${n}) (
          lib.concatLists (lib.attrValues cfg.extraFallbacks)
        );
        message = "services.llamaServers.extraFallbacks: every target must be a local, cloud or Anthropic model.";
      }
    ];

    systemd.user.services.llama-swap = {
      Unit = {
        Description = "llama-swap model router (local llama.cpp)";
        Wants = [ "llama-swap-warmup.service" ];
      };
      Service = {
        ExecStart = "${lib.getExe cfg.llamaSwapPackage} -config ${swapConfig} -listen 127.0.0.1:${toString cfg.swapPort}";
        Environment = lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment;
        Restart = "on-failure";
        RestartSec = "5s";
      }
      # llama-server children inherit the cgroup settings.
      // lib.optionalAttrs (rc.cpuWeight != null) { CPUWeight = rc.cpuWeight; }
      // lib.optionalAttrs (rc.memoryHigh != null) { MemoryHigh = rc.memoryHigh; }
      // lib.optionalAttrs (rc.memoryMax != null) { MemoryMax = rc.memoryMax; }
      // lib.optionalAttrs (rc.oomPolicy != null) { OOMPolicy = rc.oomPolicy; }
      // lib.optionalAttrs (rc.oomScoreAdjust != null) { OOMScoreAdjust = rc.oomScoreAdjust; }
      // lib.optionalAttrs (rc.allowedCPUs != null) { AllowedCPUs = rc.allowedCPUs; };
      Install.WantedBy = [ "default.target" ];
    };

    # Warmup runs in its own unit, not ExecStartPost: a cold load can take
    # 600 s, past llama-swap's 90 s start timeout. PartOf re-warms on restart.
    systemd.user.services.llama-swap-warmup = {
      Unit = {
        Description = "Warm the resident llama-swap models";
        After = [ "llama-swap.service" ];
        PartOf = [ "llama-swap.service" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.mapAttrsToList (name: m: toString (warmup name m)) residentModels;
        # Per resident: up to 20 s waiting for the router, one 600 s request.
        TimeoutStartSec = 700 * lib.length (lib.attrNames residentModels);
      };
    };

    systemd.user.services.bifrost = {
      Unit = {
        Description = "Bifrost model gateway (local-first)";
        After = [ "llama-swap.service" ];
        Wants = [ "llama-swap.service" ];
      };
      Service = {
        ExecStart = toString bifrostRunner;
        TimeoutStopSec = 10;
        Restart = "on-failure";
        RestartSec = "5s";
      }
      // lib.optionalAttrs (grc.cpuWeight != null) { CPUWeight = grc.cpuWeight; }
      // lib.optionalAttrs (grc.memoryHigh != null) { MemoryHigh = grc.memoryHigh; };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
