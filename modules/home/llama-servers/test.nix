{
  lib,
  pkgs,
  module,
  testLib,
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

  key = "/run/user/1000/bifrost-key";
  orKey = "/run/user/1000/openrouter-key";
  anthKey = "/run/user/1000/anthropic-key";

  embedder = {
    kind = "embedding";
    model = "/var/cache/models/embedder.gguf";
    devices = [ "Vulkan1" ];
    gpuLayers = 99;
    extraArgs = "--pooling last -c 4096";
  };

  eval =
    cfg:
    evalHome [
      module
      { services.llamaServers = cfg; }
    ];

  off = evalHome [ module ];

  local = eval {
    enable = true;
    masterKeyFile = key;
    models.embedder = embedder;
  };

  full = eval {
    enable = true;
    masterKeyFile = key;
    openrouterApiKeyFile = orKey;
    llamaCppPackage = pkgs.llama-cpp-vulkan;
    environment.GGML_VK_VISIBLE_DEVICES = "0,1";
    resourceControl = {
      cpuWeight = 50;
      memoryHigh = "60%";
      memoryMax = "75%";
      oomPolicy = "continue";
      oomScoreAdjust = 300;
      allowedCPUs = [ "8-15" ];
    };
    gatewayResourceControl = {
      cpuWeight = 80;
      memoryHigh = "1G";
    };
    anthropicApiKeyFile = anthKey;
    anthropicModels.claude-fast = "claude-fast-1";
    disableMcpAutoToolInject = true;
    timeouts.small-chat = 900;
    models = {
      inherit embedder;
      reranker = {
        kind = "reranker";
        model = "/var/cache/models/reranker.gguf";
      };
      small-chat = {
        model = "/var/cache/models/chat.gguf";
        gpuLayers = 0;
        ttl = 1800;
        oomScoreAdjust = 900;
      };
    };
    openrouterFallbacks.embedder = "vendor/embedder";
    overflow.embedder = {
      rpm = 30;
      timeout = 60;
    };
    cloudModels = {
      vision = "vendor/vision";
      vision-alt = "vendor/vision-alt";
    };
    extraFallbacks = {
      vision = [ "vision-alt" ];
      claude-fast = [ "vision" ];
    };
    mcpServers.search = {
      url = "https://mcp.example.org/mcp";
      envVar = "SEARCH_API_KEY";
      keyFile = "/run/user/1000/search-key";
    };
    otel = {
      enable = true;
      endpoint = "http://127.0.0.1:6006/v1/traces";
      bearerKeyFile = "/run/user/1000/phoenix-key";
    };
  };

  # Home Manager throws on any config access once an assertion fails, so a
  # rejected configuration is one that does not evaluate.
  rejected = config: !(builtins.tryEval config.services.llamaServers.enable).success;

  swap = full.services.llamaServers.swapSettings;
  bf = full.services.llamaServers.bifrostSettings;
  localBf = local.services.llamaServers.bifrostSettings;
  rule = id: lib.findFirst (r: r.id == id) null bf.governance.routing_rules;
  svc = full.systemd.user.services.llama-swap.Service;
  gw = full.systemd.user.services.bifrost.Service;
  warm = full.systemd.user.services.llama-swap-warmup;
  spaced =
    (eval {
      enable = true;
      masterKeyFile = key;
      models.embedder = embedder // {
        model = "/var/cache/my models/e.gguf";
        mmproj = "/var/cache/my models/p.gguf";
        extraArgs = "--foo --bar";
      };
    }).services.llamaServers.swapSettings.models.embedder.cmd;
in
runCases "home-llama-servers" {
  paths-with-spaces = allOf [
    (expect (lib.hasInfix "-m '/var/cache/my models/e.gguf' " spaced) "model path not quoted")
    (expect (lib.hasInfix "--mmproj '/var/cache/my models/p.gguf' " spaced) "mmproj path not quoted")
    (expect (lib.hasSuffix " --foo --bar" spaced) "extraArgs must stay unquoted")
  ];

  off-by-default = allOf [
    (expect (!off.services.llamaServers.enable) "enabled without enable = true")
    (expect (!(off.systemd.user.services ? llama-swap)) "llama-swap unit defined while off")
    (noFailedAssertions off)
  ];

  local-only = allOf [
    (noFailedAssertions local)
    (expect (local.systemd.user.services ? bifrost) "bifrost unit missing")
    (expect (!(localBf.providers ? openrouter)) "openrouter provider rendered without cloud models")
    (expect (
      localBf.providers.local.network_config.base_url == "http://127.0.0.1:8710"
    ) "local provider URL")
    (expect (local.services.llamaServers.gatewayURL == "http://127.0.0.1:4080/v1") "gatewayURL")
    (expect (lib.hasPrefix "file://" localBf.framework.pricing.pricing_url) "datasheets not local by default")
    (expect (!(local.systemd.user.services.llama-swap.Service ? CPUWeight)) "CPUWeight set by default")
  ];

  assertions = allOf [
    (expect (rejected (eval {
      enable = true;
      models.embedder = embedder;
    })) "missing gateway key accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      models.c.model = "/m.gguf";
    })) "catalog without a resident accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      models.embedder = embedder;
      cloudModels.x = "vendor/x";
    })) "cloud model without a key accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      models.embedder = embedder;
      overflow.embedder.rpm = 1;
    })) "overflow without a fallback accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      models.embedder = embedder;
      anthropicModels.c = "claude-x";
    })) "anthropic model without a key accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      anthropicApiKeyFile = anthKey;
      models.embedder = embedder;
      anthropicModels.embedder = "claude-x";
    })) "anthropic model clashing with a local one accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      models.embedder = embedder;
      timeouts.nope = 10;
    })) "timeout for an unknown model accepted")
    (expect (rejected (eval {
      enable = true;
      masterKeyFile = key;
      openrouterApiKeyFile = orKey;
      models.embedder = embedder;
      openrouterFallbacks.embedder = "vendor/embedder";
      overflow.embedder.rpm = 1;
      timeouts.embedder = 10;
    })) "timeout on an overflow model accepted")
  ];

  llama-swap-config = allOf [
    (noFailedAssertions full)
    (expect (lib.hasPrefix (builtins.unsafeDiscardStringContext (lib.getExe' pkgs.llama-cpp-vulkan "llama-server")) (builtins.unsafeDiscardStringContext swap.models.embedder.cmd)) "llamaCppPackage not used")
    (expect (lib.hasInfix "--embeddings" swap.models.embedder.cmd) "embedding flag")
    (expect (lib.hasInfix "-dev Vulkan1 -ngl 99" swap.models.embedder.cmd) "devices / gpuLayers")
    (expect (lib.hasSuffix "--pooling last -c 4096" swap.models.embedder.cmd) "extraArgs not last")
    (expect (lib.hasInfix "--reranking --pooling rank" swap.models.reranker.cmd) "reranker flags")
    (expect (lib.hasInfix "choom -n 900 --" swap.models.small-chat.cmd) "per-model oomScoreAdjust")
    (expect (swap.models.small-chat.ttl == 1800) "ttl")
    (expect (
      lib.sort lib.lessThan swap.routing.router.settings.groups.resident.members == [
        "embedder"
        "reranker"
      ]
    ) "resident group")
    (expect (swap.routing.router.settings.groups.chat.members == [ "small-chat" ]) "chat group")
    (expect (!(svc ? ExecStartPost)) "warmup blocks llama-swap's start (90 s timeout)")
    (expect (lib.length warm.Service.ExecStart == 2) "one warmup per resident")
    (expect (warm.Service.Type == "oneshot") "warmup is not a oneshot")
    (expect (warm.Service.TimeoutStartSec >= 2 * 600) "timeout shorter than the warmup requests")
    (expect (warm.Unit.After == [ "llama-swap.service" ]) "warmup not ordered after llama-swap")
    (expect (warm.Unit.PartOf == [ "llama-swap.service" ]) "warmup not restarted with llama-swap")
    (expect (
      full.systemd.user.services.llama-swap.Unit.Wants == [ "llama-swap-warmup.service" ]
    ) "llama-swap does not pull in the warmup")
  ];

  unit = allOf [
    (expect (svc.Environment == [ "GGML_VK_VISIBLE_DEVICES=0,1" ]) "environment")
    (expect (svc.CPUWeight == 50) "cpuWeight")
    (expect (svc.MemoryHigh == "60%") "memoryHigh")
    (expect (svc.OOMScoreAdjust == 300) "oomScoreAdjust")
    (expect (svc.AllowedCPUs == [ "8-15" ]) "allowedCPUs")
    (expect (svc.MemoryMax == "75%") "memoryMax")
    (expect (svc.OOMPolicy == "continue") "oomPolicy")
    (expect (!(local.systemd.user.services.llama-swap.Service ? MemoryMax)) "MemoryMax set by default")
    (expect (!(local.systemd.user.services.llama-swap.Service ? OOMPolicy)) "OOMPolicy set by default")
    (expect (gw.CPUWeight == 80) "gateway cpuWeight")
    (expect (gw.MemoryHigh == "1G") "gateway memoryHigh")
    (expect (
      !(local.systemd.user.services.bifrost.Service ? CPUWeight)
    ) "gateway CPUWeight set by default")
  ];

  bifrost-config = allOf [
    (expect (bf.providers ? openrouter) "openrouter provider missing")
    (expect (bf.providers ? "local-60s") "overflow timeout provider missing")
    (expect (
      lib.sort lib.lessThan (lib.head bf.providers.openrouter.keys).models == [
        "vendor/embedder"
        "vendor/vision"
        "vendor/vision-alt"
      ]
    ) "openrouter models")
    (expect (
      (rule "overflow-embedder").targets == [
        {
          provider = "openrouter";
          model = "vendor/embedder";
          weight = 1;
        }
      ]
    ) "overflow rule")
    (expect ((rule "route-embedder").fallbacks == [ "openrouter/vendor/embedder" ]) "fallback")
    (expect ((rule "route-vision").fallbacks == [ "openrouter/vendor/vision-alt" ]) "cloud fallback")
    (expect (
      (lib.head bf.mcp.client_configs).headers.Authorization == "env.SEARCH_API_KEY"
    ) "mcp header reference")
    (expect (lib.any (p: p.name == "otel") bf.plugins) "otel plugin")
    (expect (
      (lib.head bf.providers.anthropic.keys) == {
        name = "anthropic";
        value = "env.ANTHROPIC_API_KEY";
        models = [ "claude-fast-1" ];
        weight = 1;
      }
    ) "anthropic provider")
    (expect (!(localBf.providers ? anthropic)) "anthropic provider rendered without models")
    (expect (
      (rule "route-claude-fast").targets == [
        {
          provider = "anthropic";
          model = "claude-fast-1";
          weight = 1;
        }
      ]
    ) "anthropic route")
    (expect (
      (rule "route-claude-fast").fallbacks == [ "openrouter/vendor/vision" ]
    ) "anthropic fallback")
    (expect (bf.providers ? "local-900s") "timeouts provider missing")
    (expect (
      bf.providers.local-900s.network_config.default_request_timeout_in_seconds == 900
    ) "timeouts value")
    (expect (bf.mcp.tool_manager_config.disable_auto_tool_inject) "auto tool inject not disabled")
    (expect (!(localBf.mcp ? tool_manager_config)) "tool manager config set by default")
    (expect (!(lib.hasInfix "/run/user" (builtins.toJSON bf))) "a key path leaked into config.json")
  ];
}
