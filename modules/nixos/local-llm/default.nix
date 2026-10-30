# A local OpenAI-compatible model stack on nixpkgs' services.llama-swap:
# one llama-server per role, all on one port, routed by the request's
# `model` field.
#   - chat       /v1/chat/completions (optionally with vision, `mmproj`)
#   - embedding  /v1/embeddings
#   - rerank     /v1/rerank
# A role is served when its `model` is set. All served roles sit in one
# non-exclusive, non-swapping llama-swap group, so they stay resident
# together, and llama-swap preloads them at start.
#
# Adds per-role llama-server flags, the unit's resource policy and, when the
# OpenViking server module is imported, an ov.conf pointing it at these models.
#
# Weights are fetched by the user as fixed-output store paths, e.g.
# services.localLlm.chat.model = pkgs.fetchurl { url = ".../<file>.gguf"; hash = "..."; };
#
# Memory notes:
#   - Weights are mmapped, so experts kept in RAM (`chat.nCpuMoe`) are page
#     cache, not swap.
#   - llama-server's prompt cache (`--cache-ram`) is anonymous memory and
#     defaults to 8 GiB per server; `chat.cacheRam` bounds it, and the
#     embedding and rerank servers run without it (their inputs share no
#     prefix).
#   - A reranker is not causal: its `ubatch` caps query+document length.
{
  config,
  lib,
  options,
  pkgs,
  extraLib,
  ...
}:
let
  cfg = config.services.localLlm;

  llamaServer = lib.getExe' cfg.package "llama-server";
  serve = args: lib.concatStringsSep " " ([ llamaServer ] ++ args);
  common = [
    "--host 127.0.0.1"
    "--port \${PORT}"
  ]
  ++ cfg.commonArgs;

  weightsType = lib.types.nullOr (lib.types.either lib.types.package lib.types.str);

  modelOption =
    role:
    lib.mkOption {
      type = weightsType;
      default = null;
      example = lib.literalExpression ''
        pkgs.fetchurl {
          url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
          hash = "sha256-...";
        }
      '';
      description = ''
        GGUF weights of the ${role} model: a fetched store path or a path
        outside the store. Null leaves the role unserved.
      '';
    };

  nameOption =
    default:
    lib.mkOption {
      type = lib.types.str;
      inherit default;
      description = "Model id clients send in the `model` field.";
    };

  extraArgsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "Extra llama-server arguments after the generated ones.";
  };

  ubatchArgs = n: [
    "-b ${toString n}"
    "-ub ${toString n}"
  ];

  roles = {
    chat = {
      inherit (cfg.chat) name model;
      cmd = serve (
        common
        ++ [ "-m ${lib.escapeShellArg "${cfg.chat.model}"}" ]
        ++ lib.optional (cfg.chat.mmproj != null) "--mmproj ${lib.escapeShellArg "${cfg.chat.mmproj}"}"
        ++ lib.optional (cfg.chat.mmproj != null && !cfg.chat.mmprojOffload) "--no-mmproj-offload"
        ++ lib.optional (cfg.chat.nCpuMoe != null) "--n-cpu-moe ${toString cfg.chat.nCpuMoe}"
        ++ [
          "-c ${toString cfg.chat.contextSize}"
          "-np ${toString cfg.chat.parallel}"
          # One KV pool for all slots: a split pool caps each request at
          # -c / -np.
          "--kv-unified"
          "--cache-ram ${toString cfg.chat.cacheRam}"
          "--jinja"
        ]
        ++ lib.optional (cfg.chat.threads != null) "-t ${toString cfg.chat.threads}"
        ++ lib.optionals (cfg.chat.ubatch != null) (ubatchArgs cfg.chat.ubatch)
        ++ lib.optional cfg.chat.mlock "--mlock"
        ++ cfg.chat.extraArgs
      );
      extra = {
        inherit (cfg.chat) concurrencyLimit;
      }
      // lib.optionalAttrs (cfg.chat.ttl != null) { inherit (cfg.chat) ttl; };
    };
    embedding = {
      inherit (cfg.embedding) name model;
      cmd = serve (
        common
        ++ [
          "-m ${lib.escapeShellArg "${cfg.embedding.model}"}"
          "--embedding"
        ]
        ++ lib.optional (cfg.embedding.pooling != null) "--pooling ${cfg.embedding.pooling}"
        ++ [ "-c ${toString cfg.embedding.contextSize}" ]
        ++ ubatchArgs cfg.embedding.ubatch
        ++ [ "--cache-ram 0" ]
        ++ cfg.embedding.extraArgs
      );
      extra = { };
    };
    rerank = {
      inherit (cfg.rerank) name model;
      cmd = serve (
        common
        ++ [
          "-m ${lib.escapeShellArg "${cfg.rerank.model}"}"
          "--reranking"
          "--pooling rank"
          "-c ${toString (cfg.rerank.ubatch * cfg.rerank.parallel)}"
          "-np ${toString cfg.rerank.parallel}"
        ]
        ++ ubatchArgs cfg.rerank.ubatch
        ++ [ "--cache-ram 0" ]
        ++ cfg.rerank.extraArgs
      );
      extra = {
        inherit (cfg.rerank) concurrencyLimit;
      };
    };
  };

  served = lib.filterAttrs (_: r: r.model != null) roles;
  servedNames = lib.mapAttrsToList (_: r: r.name) served;

  ov = cfg.openviking;
  ovStateDir = "/var/lib/openviking";

  # Provider blocks in the shape of the OpenViking modules' options.
  # llama-swap does no auth, but the OpenAI client refuses an empty key.
  openvikingProviders = {
    vlm = {
      provider = "openai";
      apiBase = cfg.chatURL;
      apiKey = "local";
      model = cfg.chat.name;
      maxConcurrent = cfg.chat.parallel;
      inherit (ov) timeout;
    };
    embedding = {
      provider = "openai";
      apiBase = cfg.chatURL;
      apiKey = "local";
      model = cfg.embedding.name;
      inherit (cfg.embedding) dimension;
    };
  }
  // lib.optionalAttrs (cfg.rerank.model != null) {
    rerank = {
      provider = "openai";
      apiBase = cfg.rerankURL;
      apiKey = "local";
      model = cfg.rerank.name;
      # Half the ubatch leaves margin for the server's chars/4 token
      # estimate, which undercounts code.
      maxInputTokens = cfg.rerank.ubatch / 2;
    };
  };

  ovConf = pkgs.writeText "openviking-local-llm.conf" (
    builtins.toJSON (
      extraLib.openviking.mkOvConf {
        inherit (ov) workspace;
        inherit (openvikingProviders) vlm embedding;
        rerank =
          let
            r = openvikingProviders.rerank;
          in
          if openvikingProviders ? rerank then
            {
              inherit (r) provider model;
              api_base = r.apiBase;
              api_key = r.apiKey;
              max_input_tokens = r.maxInputTokens;
            }
          else
            null;
        extra = ov.extraSettings;
      }
    )
  );
in
{
  options.services.localLlm = {
    enable = lib.mkEnableOption "a local OpenAI-compatible model stack (llama-swap with chat, embedding and rerank servers)";

    package = lib.mkPackageOption pkgs "llama-cpp" {
      example = "llama-cpp-vulkan";
      extraDescription = "The llama.cpp build providing llama-server; pick the GPU backend per host.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Loopback port llama-swap listens on.";
    };

    commonArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "-ngl 999"
        "-fa on"
        # Halves KV memory; embeddings stay at cosine 0.999 against f16.
        "-ctk q8_0"
        "-ctv q8_0"
      ];
      description = ''
        llama-server arguments every role gets, after `--host` and `--port`.
        The default offloads every layer to the GPU, enables flash
        attention and stores the KV cache as q8_0.
      '';
    };

    gpuAccess = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Put the llama-swap unit in the `render` and `video` groups. nixpkgs'
        unit runs as a DynamicUser with PrivateDevices off but no group
        beyond its own, so Vulkan and ROCm cannot open the `root:render`
        0660 nodes under /dev/dri or /dev/kfd and llama.cpp falls back to
        the CPU. Turn it off on CPU-only hosts.

        No DeviceAllow is added: the unit has no device policy, and adding
        one would close every device not listed (such as the NVIDIA nodes).
      '';
    };

    healthCheckTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 600;
      description = "Seconds llama-swap waits for a server to come up; large weights page in slowly on a cold start.";
    };

    chat = {
      model = modelOption "chat";
      name = nameOption "chat";

      mmproj = lib.mkOption {
        type = weightsType;
        default = null;
        description = "Vision projector GGUF (`--mmproj`); null serves text only.";
      };

      mmprojOffload = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Keep the vision projector on the GPU. When false, image encoding runs on the CPU.";
      };

      nCpuMoe = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.unsigned;
        default = null;
        example = 40;
        description = ''
          Layers of a MoE model whose expert weights stay in system RAM
          (`--n-cpu-moe`), the knob for fitting VRAM: attention, shared
          weights and KV cache stay on the GPU. Lower values put more on the
          GPU (faster, more VRAM).
        '';
      };

      contextSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 32768;
        description = "Total context (`-c`), shared across the `parallel` slots.";
      };

      parallel = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Concurrent request slots (`-np`).";
      };

      ttl = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Seconds of inactivity before llama-swap unloads the chat model; null keeps it resident.";
      };

      cacheRam = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 2048;
        description = ''
          Host-RAM prompt cache in MiB (`--cache-ram`); 0 disables it. It lets
          a request reuse the KV of an earlier prompt with the same prefix.
          llama-server's own default is 8192.
        '';
      };

      concurrencyLimit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 64;
        description = ''
          In-flight requests llama-swap accepts before answering 429 (its
          own default is 10). Requests past the `parallel` slots wait in
          llama-server's queue, so a lower limit fails fast instead.
        '';
      };

      threads = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "CPU threads (`-t`); null keeps llama-server's default.";
      };

      ubatch = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = ''
          Logical and physical batch size (`-b`/`-ub`); null keeps
          llama-server's defaults. Larger ubatches let prompt processing run
          CPU-resident experts on the GPU, at more compute-buffer VRAM.
        '';
      };

      mlock = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Lock the mmapped weights in RAM (`--mlock`), so memory pressure
          cannot evict them. Pins the whole model while it is loaded.
        '';
      };

      extraArgs = extraArgsOption // {
        example = [
          "--chat-template-kwargs '{\"enable_thinking\":false}'"
          "--temp 0.7"
          "--top-p 0.8"
        ];
      };
    };

    embedding = {
      model = modelOption "embedding";
      name = nameOption "embedding";

      dimension = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        example = 2560;
        description = "Output dimension of the embedding model, for clients that need it (the OpenViking config).";
      };

      pooling = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "last";
        description = "Pooling type (`--pooling`); null keeps the model's own.";
      };

      contextSize = lib.mkOption {
        type = lib.types.ints.positive;
        default = 8192;
        description = "Context (`-c`) of the embedding server.";
      };

      ubatch = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1024;
        description = "Logical and physical batch size (`-b`/`-ub`).";
      };

      extraArgs = extraArgsOption;
    };

    rerank = {
      model = modelOption "rerank" // {
        description = ''
          GGUF weights of the reranker: a fetched store path or a path
          outside the store. Null leaves the role unserved. The GGUF must
          keep the classification head and rank pooling (a conversion made
          with llama.cpp's convert_hf_to_gguf.py does); others score near 0.
        '';
      };
      name = nameOption "rerank";

      parallel = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Concurrent request slots (`-np`); the context is `ubatch` per slot.";
      };

      ubatch = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2048;
        description = ''
          Logical and physical batch size (`-b`/`-ub`). A query+document pair
          longer than this is rejected, so clients must cap their input
          below it.
        '';
      };

      concurrencyLimit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 64;
        description = "In-flight requests llama-swap accepts before answering 429.";
      };

      extraArgs = extraArgsOption;
    };

    resourceControl = {
      cpuWeight = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 10000);
        default = null;
        example = 20;
        description = "CPUWeight of llama-swap and its servers; null keeps systemd's default.";
      };

      ioWeight = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between 1 10000);
        default = null;
        example = 20;
        description = "IOWeight of llama-swap and its servers; null keeps systemd's default.";
      };

      nice = lib.mkOption {
        type = lib.types.nullOr (lib.types.ints.between (-20) 19);
        default = null;
        example = 5;
        description = "Nice level of llama-swap and its servers; null keeps the default.";
      };
    };

    openviking = {
      enable = lib.mkEnableOption ''
        pointing the OpenViking server (services.openviking-server) at this
        stack: its `configFile` defaults to a generated ov.conf whose vlm,
        embedding and rerank providers are the local models, and the server
        starts after llama-swap. Needs the chat and embedding roles and
        `embedding.dimension`'';

      workspace = lib.mkOption {
        type = lib.types.str;
        default = "${ovStateDir}/.openviking";
        description = "OpenViking storage workspace written into the generated ov.conf.";
      };

      timeout = lib.mkOption {
        type = lib.types.ints.positive;
        default = 1200;
        description = "Seconds OpenViking waits on a chat request; requests can queue behind every slot.";
      };

      extraSettings = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = { };
        example = {
          server.with_bot = true;
        };
        description = "Top-level ov.conf sections merged over the generated ones.";
      };
    };

    chatURL = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://127.0.0.1:${toString cfg.port}/v1";
      defaultText = lib.literalExpression ''"http://127.0.0.1:''${toString port}/v1"'';
      description = "OpenAI API base of every role (chat, embeddings, rerank).";
    };

    rerankURL = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${cfg.chatURL}/rerank";
      defaultText = lib.literalExpression ''"''${chatURL}/rerank"'';
      description = "Full rerank endpoint, for clients that POST to it directly.";
    };

    openvikingProviders = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      readOnly = true;
      default = openvikingProviders;
      defaultText = lib.literalMD "`vlm`, `embedding` and (when served) `rerank` blocks for this stack";
      description = ''
        Provider settings in the shape of the OpenViking modules' `vlm`,
        `embedding` and `rerank` options, so a per-user server
        (programs.openviking-server) can take them from the system config.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        assertions = [
          {
            assertion = served != { };
            message = "services.localLlm: set at least one of chat.model, embedding.model and rerank.model.";
          }
          {
            assertion = lib.allUnique servedNames;
            message = "services.localLlm: the chat, embedding and rerank names must differ.";
          }
          {
            assertion = ov.enable -> options.services ? openviking-server;
            message = "services.localLlm.openviking.enable needs the openviking-server NixOS module.";
          }
          {
            assertion =
              ov.enable
              -> cfg.chat.model != null && cfg.embedding.model != null && cfg.embedding.dimension != null;
            message = "services.localLlm.openviking needs chat.model, embedding.model and embedding.dimension.";
          }
        ];

        systemd.services.llama-swap = {
          # llama-swap's GPU monitor shells out to nvidia-smi.
          path = lib.mkIf (
            lib.elem "nvidia" config.services.xserver.videoDrivers && config.hardware.nvidia.enabled
          ) [ config.hardware.nvidia.package.bin ];
          # The servers are children of llama-swap and share its cgroup.
          serviceConfig =
            lib.optionalAttrs cfg.gpuAccess {
              SupplementaryGroups = [
                "render"
                "video"
              ];
            }
            // lib.optionalAttrs (cfg.resourceControl.cpuWeight != null) {
              CPUWeight = cfg.resourceControl.cpuWeight;
            }
            // lib.optionalAttrs (cfg.resourceControl.ioWeight != null) {
              IOWeight = cfg.resourceControl.ioWeight;
            }
            // lib.optionalAttrs (cfg.resourceControl.nice != null) { Nice = cfg.resourceControl.nice; }
            // lib.optionalAttrs cfg.chat.mlock { LimitMEMLOCK = "infinity"; };
        };

        services.llama-swap = {
          enable = true;
          listenAddress = "127.0.0.1";
          inherit (cfg) port;
          settings = {
            inherit (cfg) healthCheckTimeout;
            # The servers bind 127.0.0.1; llama-swap's default proxy target
            # `localhost` tries [::1] first.
            models = lib.mapAttrs' (
              _: r:
              lib.nameValuePair r.name (
                {
                  inherit (r) cmd;
                  proxy = "http://127.0.0.1:\${PORT}";
                }
                // r.extra
              )
            ) served;
            # One non-exclusive, non-swapping group: loading one member never
            # evicts another.
            groups.local-llm = {
              swap = false;
              exclusive = false;
              members = servedNames;
            };
            hooks.on_startup.preload = servedNames;
          };
        };
      }

      # Only when some module declares services.openviking-server.
      (lib.optionalAttrs (options.services ? openviking-server) (
        lib.mkIf ov.enable {
          services.openviking-server.configFile = lib.mkDefault ovConf;
          systemd.services.openviking-server = {
            after = [ "llama-swap.service" ];
            wants = [ "llama-swap.service" ];
          };
        }
      ))
    ]
  );
}
