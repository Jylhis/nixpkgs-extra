{
  lib,
  module,
  nixosModules,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    allOf
    noFailedAssertions
    failedAssertions
    runCases
    ;

  eval = extra: evalNixos ([ module ] ++ extra);
  withCfg = cfg: eval [ { services.localLlm = cfg; } ];

  off = eval [ ];

  chatOnly = withCfg {
    enable = true;
    chat.model = "/var/cache/models/chat.gguf";
  };

  full = withCfg {
    enable = true;
    port = 8711;
    chat = {
      model = "/var/cache/models/chat.gguf";
      mmproj = "/var/cache/models/mmproj.gguf";
      mmprojOffload = false;
      nCpuMoe = 24;
      ttl = 1800;
      mlock = true;
      extraArgs = [ "--temp 0.7" ];
    };
    embedding = {
      model = "/var/cache/models/embedding.gguf";
      name = "embedder";
      pooling = "last";
      dimension = 2560;
    };
    rerank.model = "/var/cache/models/rerank.gguf";
    resourceControl = {
      cpuWeight = 20;
      ioWeight = 20;
      nice = 5;
    };
  };

  ovStack = {
    enable = true;
    chat.model = "/var/cache/models/chat.gguf";
    embedding = {
      model = "/var/cache/models/embedding.gguf";
      dimension = 1024;
    };
    openviking.enable = true;
  };
  withOpenviking = eval [
    nixosModules.openviking-server
    {
      services.openviking-server.enable = true;
      services.localLlm = ovStack;
    }
  ];
  openvikingMissing = withCfg ovStack;

  failsWith = config: fragment: lib.any (lib.hasInfix fragment) (failedAssertions config);

  models = full.services.llama-swap.settings.models;
  sc = full.systemd.services.llama-swap.serviceConfig;
  providers = full.services.localLlm.openvikingProviders;
in
runCases "nixos-local-llm" {
  off-by-default = allOf [
    (expect (!off.services.localLlm.enable) "enabled without enable = true")
    (expect (!off.services.llama-swap.enable) "llama-swap enabled while off")
    (noFailedAssertions off)
  ];

  chat-only = allOf [
    (noFailedAssertions chatOnly)
    (expect chatOnly.services.llama-swap.enable "llama-swap not enabled")
    (expect (chatOnly.services.llama-swap.listenAddress == "127.0.0.1") "not loopback")
    (expect (
      lib.attrNames chatOnly.services.llama-swap.settings.models == [ "chat" ]
    ) "unset roles served")
    (expect (lib.hasInfix "-m /var/cache/models/chat.gguf" chatOnly.services.llama-swap.settings.models.chat.cmd) "chat weights")
    (expect (lib.hasInfix "--cache-ram 2048" chatOnly.services.llama-swap.settings.models.chat.cmd) "cacheRam default")
    (expect (
      !(lib.hasInfix "--mmproj" chatOnly.services.llama-swap.settings.models.chat.cmd)
    ) "mmproj without one set")
    (expect (chatOnly.services.localLlm.chatURL == "http://127.0.0.1:8080/v1") "chatURL")
  ];

  full-stack = allOf [
    (noFailedAssertions full)
    (expect (full.services.llama-swap.port == 8711) "port")
    (expect (
      lib.sort lib.lessThan (lib.attrNames models) == [
        "chat"
        "embedder"
        "rerank"
      ]
    ) "role names")
    (expect (lib.hasInfix "--mmproj /var/cache/models/mmproj.gguf" models.chat.cmd) "mmproj")
    (expect (lib.hasInfix "--no-mmproj-offload" models.chat.cmd) "mmprojOffload")
    (expect (lib.hasInfix "--n-cpu-moe 24" models.chat.cmd) "nCpuMoe")
    (expect (lib.hasInfix "--mlock" models.chat.cmd) "mlock flag")
    (expect (lib.hasSuffix "--temp 0.7" models.chat.cmd) "extraArgs not last")
    (expect (models.chat.ttl == 1800) "ttl")
    (expect (models.chat.concurrencyLimit == 64) "concurrencyLimit")
    (expect (lib.hasInfix "--embedding --pooling last -c 8192 -b 1024 -ub 1024" models.embedder.cmd) "embedding flags")
    (expect (lib.hasInfix "--reranking --pooling rank -c 4096 -np 2 -b 2048 -ub 2048" models.rerank.cmd) "rerank flags")
    (expect (full.services.llama-swap.settings.hooks.on_startup.preload != [ ]) "no preload")
    (expect (
      lib.sort lib.lessThan full.services.llama-swap.settings.groups.local-llm.members == [
        "chat"
        "embedder"
        "rerank"
      ]
    ) "resident group")
  ];

  unit-policy = allOf [
    (expect (sc.LimitMEMLOCK == "infinity") "mlock limit")
    (expect (sc.CPUWeight == 20) "cpuWeight")
    (expect (sc.IOWeight == 20) "ioWeight")
    (expect (sc.Nice == 5) "nice")
    (expect (!(chatOnly.systemd.services.llama-swap.serviceConfig ? Nice)) "nice set by default")
  ];

  paths-with-spaces =
    let
      cmds =
        (withCfg {
          enable = true;
          chat = {
            model = "/var/cache/my models/chat.gguf";
            mmproj = "/var/cache/my models/proj.gguf";
            extraArgs = [ "--foo bar" ];
          };
          embedding.model = "/var/cache/my models/emb.gguf";
          rerank.model = "/var/cache/my models/rr.gguf";
        }).services.llama-swap.settings.models;
    in
    allOf [
      (expect (lib.hasInfix "-m '/var/cache/my models/chat.gguf' " cmds.chat.cmd) "chat path")
      (expect (lib.hasInfix "--mmproj '/var/cache/my models/proj.gguf' " cmds.chat.cmd) "mmproj path")
      (expect (lib.hasSuffix " --foo bar" cmds.chat.cmd) "extraArgs must stay unquoted")
      (expect (lib.hasInfix "-m '/var/cache/my models/emb.gguf' " cmds.embedding.cmd) "embedding path")
      (expect (lib.hasInfix "-m '/var/cache/my models/rr.gguf' " cmds.rerank.cmd) "rerank path")
    ];

  gpu-access = allOf [
    (expect (
      chatOnly.systemd.services.llama-swap.serviceConfig.SupplementaryGroups == [
        "render"
        "video"
      ]
    ) "no GPU groups by default")
    (expect (!chatOnly.systemd.services.llama-swap.serviceConfig.PrivateDevices) "devices hidden")
    (expect (
      !(chatOnly.systemd.services.llama-swap.serviceConfig ? DeviceAllow)
    ) "DeviceAllow would close the other GPU nodes")
    (expect (
      !(
        (withCfg {
          enable = true;
          chat.model = "/var/cache/models/chat.gguf";
          gpuAccess = false;
        }).systemd.services.llama-swap.serviceConfig
          ? SupplementaryGroups
      )
    ) "gpuAccess = false still adds groups")
  ];

  openviking-providers = allOf [
    (expect (providers.vlm.apiBase == "http://127.0.0.1:8711/v1") "vlm apiBase")
    (expect (providers.vlm.maxConcurrent == 2) "vlm maxConcurrent")
    (expect (providers.embedding.model == "embedder") "embedding model name")
    (expect (providers.embedding.dimension == 2560) "embedding dimension")
    (expect (providers.rerank.apiBase == "http://127.0.0.1:8711/v1/rerank") "rerank endpoint")
    (expect (providers.rerank.maxInputTokens == 1024) "rerank input cap")
    (expect (
      !(chatOnly.services.localLlm.openvikingProviders ? rerank)
    ) "rerank provider without a reranker")
  ];

  openviking-integration = allOf [
    (noFailedAssertions withOpenviking)
    (expect (lib.hasSuffix "openviking-local-llm.conf" (toString withOpenviking.services.openviking-server.configFile)) "configFile not generated")
    (expect (lib.elem "llama-swap.service" withOpenviking.systemd.services.openviking-server.after) "ordering")
    (expect (failsWith openvikingMissing "openviking-server NixOS module") "missing module accepted")
    (expect (failsWith (withCfg (
      ovStack // { embedding.model = "/var/cache/models/embedding.gguf"; }
    )) "embedding.dimension") "missing dimension accepted")
  ];

  assertions = allOf [
    (expect (failsWith (withCfg { enable = true; }) "at least one") "empty stack accepted")
    (expect (failsWith (withCfg {
      enable = true;
      chat.model = "/a.gguf";
      embedding = {
        model = "/b.gguf";
        name = "chat";
      };
    }) "must differ") "duplicate names accepted")
  ];
}
