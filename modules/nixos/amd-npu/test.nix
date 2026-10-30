{
  lib,
  pkgs,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    allOf
    failedAssertions
    noFailedAssertions
    runCases
    ;

  eval =
    cfg:
    evalNixos [
      module
      {
        boot.kernelPackages = pkgs.linuxPackages_latest;
        hardware.amd-npu = cfg;
      }
    ];

  off = evalNixos [ module ];
  npuOnly = eval { enable = true; };
  on = eval {
    enable = true;
    enableLemonade = true;
    enableFastFlowLM = true;
    lemonade.user = "lemonade";
  };
  gpuOnly = eval {
    enable = true;
    enableNPU = false;
    enableLemonade = true;
    enableROCm = true;
    enableVulkan = true;
    lemonade = {
      user = "lemonade";
      desktopApp.enable = false;
    };
  };
  vllm = eval {
    enable = true;
    enableLemonade = true;
    enableROCm = true;
    enableVllm = true;
    lemonade.user = "lemonade";
  };
  vllmWithoutRocm = eval {
    enable = true;
    enableLemonade = true;
    enableVllm = true;
    lemonade.user = "lemonade";
  };
  memlock = eval {
    enable = true;
    unlimitedMemlock = true;
  };
  ds4Default = eval {
    enable = true;
    ds4 = {
      enable = true;
      user = "ds4";
      model = "/var/lib/ds4/model.gguf";
    };
  };
  ds4 = eval {
    enable = true;
    ds4 = {
      enable = true;
      package = pkgs.hello;
      user = "ds4";
      model = "/var/lib/ds4/my model.gguf";
      ctx = 8192;
      extraArgs = [ "--kv-disk-dir=/var/lib/ds4/kv 100%" ];
    };
  };
  gtt = eval {
    enable = true;
    gpuMemory = {
      ttmSizeGiB = 96;
      pagePoolSizeGiB = 8;
    };
  };
  poolWithoutTtm = eval {
    enable = true;
    gpuMemory.pagePoolSizeGiB = 8;
  };

  lemond = config: config.systemd.services.lemond;
  hasFailure = config: needle: lib.any (lib.hasInfix needle) (failedAssertions config);
in
runCases "nixos-amd-npu" {
  off-by-default = allOf [
    (expect (!(off.systemd.services ? lemond)) "lemond present when disabled")
    (expect (!(lib.elem "amdxdna" off.boot.kernelModules)) "amdxdna loaded when disabled")
  ];

  # enable alone wires the NPU and nothing that listens or runs foreign ELFs.
  npu-only-by-default = allOf [
    (noFailedAssertions npuOnly)
    (expect (lib.elem "amdxdna" npuOnly.boot.kernelModules) "amdxdna not loaded")
    (expect (!(npuOnly.systemd.services ? lemond)) "lemond enabled by enable alone")
    (expect (
      !(lib.any (l: l.item == "memlock") npuOnly.security.pam.loginLimits)
    ) "memlock raised for all video/render users by enable alone")
    (expect (!npuOnly.programs.nix-ld.enable) "nix-ld enabled by enable alone")
    (expect (
      !(npuOnly.environment.sessionVariables ? FLM_DISABLE_UPDATE_CHECK)
    ) "FastFlowLM enabled by enable alone")
    (expect (
      !(npuOnly.environment.etc ? "lemonade/backends/llamacpp-cpu")
    ) "lemonade backends wired by enable alone")
  ];

  enabled = allOf [
    (noFailedAssertions on)
    (expect (lib.elem "amdxdna" on.boot.kernelModules) "amdxdna not loaded")
    (expect (lib.hasPrefix "\"${on.hardware.amd-npu.lemonade.package}/bin/lemond\" " (lemond on).serviceConfig.ExecStart) "lemond does not run lemonade.package")
    (expect ((lemond on).serviceConfig.User == "lemonade") "lemond user not wired")
    (expect ((lemond on).environment ? XILINX_XRT) "XILINX_XRT missing with the NPU enabled")
    (expect (on.environment.etc ? "lemonade/backends/llamacpp-cpu") "CPU backend symlink missing")
    (expect (
      !(on.environment.etc ? "lemonade/backends/sdcpp-cpu")
    ) "image generation on without enableImageGen")
    # systemd's default accel rule (render, 0666) must win; a later rule
    # narrowing it to video/0660 locks out render-only users.
    (expect (
      !(lib.hasInfix "accel" on.services.udev.extraRules)
    ) "udev rule overrides systemd's accel default")
    (expect (lib.all (g: lib.elem g (lemond on).serviceConfig.SupplementaryGroups) [
      "render"
      "video"
    ]) "lemond lacks render/video for the NPU and GPU device nodes")
  ];

  gpu-only = allOf [
    (noFailedAssertions gpuOnly)
    (expect (!(lib.elem "amdxdna" gpuOnly.boot.kernelModules)) "amdxdna loaded with enableNPU = false")
    (expect (!((lemond gpuOnly).environment ? XILINX_XRT)) "XILINX_XRT set with enableNPU = false")
    (expect (
      gpuOnly.environment.etc ? "lemonade/backends/llamacpp-rocm"
    ) "ROCm backend symlink missing")
    (expect (
      gpuOnly.environment.etc ? "lemonade/backends/llamacpp-vulkan"
    ) "Vulkan backend symlink missing")
  ];

  vllm = allOf [
    (noFailedAssertions vllm)
    (expect (vllm.environment.etc ? "lemonade/backends/vllm-rocm") "vLLM backend symlink missing")
  ];
  vllm-needs-rocm = expect (hasFailure vllmWithoutRocm "enableVllm requires") "enableVllm without ROCm passed";

  memlock-opt-in = expect (lib.any (
    l: l.domain == "@render" && l.item == "memlock" && l.value == "unlimited"
  ) memlock.security.pam.loginLimits) "unlimitedMemlock does not raise the render group's memlock";

  ds4-default-package = allOf [
    (noFailedAssertions ds4Default)
    (expect (lib.hasPrefix "\"${ds4Default.hardware.amd-npu.ds4.package}/bin/ds4-server\" " ds4Default.systemd.services.ds4-server.serviceConfig.ExecStart) "ds4-server does not run ds4.package")
    (expect (
      lib.getName ds4Default.hardware.amd-npu.ds4.package == "ds4"
    ) "ds4.package does not default to pkgs.ds4")
  ];
  ds4 = allOf [
    (noFailedAssertions ds4)
    (expect (lib.hasInfix ''"--ctx" "8192"'' ds4.systemd.services.ds4-server.serviceConfig.ExecStart) "ds4 ctx not passed")
    (expect (lib.hasInfix ''"--model" "/var/lib/ds4/my model.gguf"'' ds4.systemd.services.ds4-server.serviceConfig.ExecStart) "ds4 model path with a space not quoted")
    (expect (lib.hasInfix ''"--kv-disk-dir=/var/lib/ds4/kv 100%%"'' ds4.systemd.services.ds4-server.serviceConfig.ExecStart) "ds4 extraArgs not escaped for systemd")
  ];

  gtt-pages = expect (lib.hasInfix "pages_limit=${toString (96 * 262144)} page_pool_size=${toString (8 * 262144)}" gtt.boot.extraModprobeConfig) "ttm modprobe options wrong";
  pool-needs-ttm = expect (hasFailure poolWithoutTtm "requires ttmSizeGiB") "pagePoolSizeGiB without ttmSizeGiB passed";
}
