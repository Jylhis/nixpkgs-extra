# AMD Ryzen AI inference stack: the XDNA NPU (amdxdna, XRT, FastFlowLM), the
# Lemonade server and its llama.cpp / whisper.cpp / stable-diffusion.cpp /
# vLLM backends on ROCm or Vulkan, and an optional ds4-server unit.
#
# Options live under hardware.amd-npu (next to hardware.amdgpu) rather than
# services.*, since the core is hardware wiring. `enable` alone only wires
# the NPU; the Lemonade service, FastFlowLM and image generation are opt-in.
#
# Adapted from noamsto/nix-amd-ai (MIT), rev 9e175bc, modules/amd-npu.nix:
# this repo's packages come from extraPkgs and are overridable through
# package options; nixpkgs packages (llama-cpp, whisper-cpp,
# stable-diffusion-cpp, rocmPackages) stay as they are. AMD's unfree Ryzen AI
# Software is not needed by any path here.
#
# Copyright (c) 2026 Noam Stolero
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
{
  config,
  lib,
  pkgs,
  utils,
  extraPkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    mkIf
    mkDefault
    types
    optionalString
    optional
    optionals
    optionalAttrs
    versionAtLeast
    concatStringsSep
    ;
  cfg = config.hardware.amd-npu;

  lemonadePackage = cfg.lemonade.package;

  vllmPkg = cfg.vllmPackage;

  # 4096-byte pages: pages = GiB * 1024^3 / 4096 = GiB * 262144.
  gttPages = gib: gib * 262144;

  # Optional " page_pool_size=…" clause appended to the ttm modprobe line.
  ttmPagePoolClause = optionalString (
    cfg.gpuMemory.pagePoolSizeGiB != null
  ) " page_pool_size=${toString (gttPages cfg.gpuMemory.pagePoolSizeGiB)}";

  xrtPrefix = "${cfg.xrtPackage}/opt/xilinx/xrt";

  xrt-combined = pkgs.runCommand "xrt-combined" { } ''
    mkdir -p $out
    cp -rs ${xrtPrefix}/* $out/
    chmod -R u+w $out/lib
    ln -sf ${cfg.xrtPluginPackage}/opt/xilinx/xrt/lib/libxrt_driver_xdna* $out/lib/
  '';

  # XRT (NPU) libs only present when enableNPU; ROCm libs trail them.
  ldLibraryPath = concatStringsSep ":" (
    optional cfg.enableNPU "${xrt-combined}/lib"
    ++ optional cfg.enableROCm "${pkgs.rocmPackages.clr}/lib"
  );

  pathList =
    optional cfg.enableNPU xrt-combined ++ optional cfg.enableFastFlowLM cfg.fastflowlmPackage;

  # Stable /etc paths for lemonade's backend binaries: config.json caches
  # them, so a raw store path would dangle after a bump and GC.
  lemonadeBackendBin = name: "/etc/lemonade/backends/${name}";
  lemonadeBackendEtc =
    optionalAttrs cfg.enableLemonade {
      "lemonade/backends/llamacpp-cpu".source = "${pkgs.llama-cpp}/bin/llama-server";
      "lemonade/backends/whispercpp-cpu".source = "${pkgs.whisper-cpp}/bin/whisper-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableImageGen) {
      "lemonade/backends/sdcpp-cpu".source = "${pkgs.stable-diffusion-cpp}/bin/sd-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableROCm) {
      "lemonade/backends/llamacpp-rocm".source = "${pkgs.llama-cpp-rocm}/bin/llama-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableROCm && cfg.enableImageGen) {
      "lemonade/backends/sdcpp-rocm".source = "${pkgs.stable-diffusion-cpp-rocm}/bin/sd-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableROCm && cfg.enableVllm) {
      "lemonade/backends/vllm-rocm".source = "${vllmPkg}/bin/vllm-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableVulkan) {
      "lemonade/backends/llamacpp-vulkan".source = "${pkgs.llama-cpp-vulkan}/bin/llama-server";
      "lemonade/backends/whispercpp-vulkan".source = "${pkgs.whisper-cpp-vulkan}/bin/whisper-server";
    }
    // optionalAttrs (cfg.enableLemonade && cfg.enableVulkan && cfg.enableImageGen) {
      "lemonade/backends/sdcpp-vulkan".source = "${pkgs.stable-diffusion-cpp-vulkan}/bin/sd-server";
    };

  # defaults.json seed merged over lemonade's packaged defaults (via the
  # LEMONADE_DEFAULTS_PATH patch in lemonade-server). v10.7.0 removed the env
  # hooks for these keys.
  lemonadeDefaults = {
    # 0 disables lemond's 300s cutoff (lemonade#1364), but vLLM reads it as
    # its startup timeout and 0 means no attempts: use a large finite value.
    # See noamsto/nix-amd-ai#63.
    global_timeout = if cfg.enableVllm then 3600 else 0;
    llamacpp = {
      args = "--flash-attn ${cfg.lemonade.flashAttn}";
      cpu_bin = lemonadeBackendBin "llamacpp-cpu";
    }
    // optionalAttrs cfg.enableROCm { rocm_bin = lemonadeBackendBin "llamacpp-rocm"; }
    // optionalAttrs cfg.enableVulkan { vulkan_bin = lemonadeBackendBin "llamacpp-vulkan"; };
    whispercpp = {
      cpu_bin = lemonadeBackendBin "whispercpp-cpu";
    }
    // optionalAttrs cfg.enableVulkan { vulkan_bin = lemonadeBackendBin "whispercpp-vulkan"; };
  }
  // optionalAttrs cfg.enableFastFlowLM {
    # v10.10.0 gates FLM-on-PATH discovery behind this flag. See
    # noamsto/nix-amd-ai#62.
    flm.prefer_system = true;
  }
  // optionalAttrs cfg.enableImageGen {
    sdcpp = {
      cpu_bin = lemonadeBackendBin "sdcpp-cpu";
    }
    // optionalAttrs cfg.enableROCm { rocm_bin = lemonadeBackendBin "sdcpp-rocm"; }
    // optionalAttrs cfg.enableVulkan { vulkan_bin = lemonadeBackendBin "sdcpp-vulkan"; };
  }
  // optionalAttrs (cfg.enableROCm && cfg.enableVllm) {
    vllm.rocm_bin = lemonadeBackendBin "vllm-rocm";
  };
  lemonadeDefaultsFile = (pkgs.formats.json { }).generate "lemonade-defaults.json" (
    lib.recursiveUpdate lemonadeDefaults cfg.lemonade.settings
  );

  # LEMONADE_DEFAULTS_PATH only seeds config.json on first run; re-apply our
  # values each start. See noamsto/nix-amd-ai#67 and #68.
  lemonadeReconcile = pkgs.writeShellApplication {
    name = "lemond-reconcile-config";
    runtimeInputs = [
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      config="''${LEMONADE_CACHE_DIR:-''${HOME:-}/.cache/lemonade}/config.json"
      [ -f "$config" ] || exit 0

      tmp="$config.nix-reconcile"
      if jq -s '.[0] * .[1]' "$config" ${lemonadeDefaultsFile} >"$tmp"; then
        # lemond may have tightened the mode; rename would silently widen it back.
        chmod --reference="$config" "$tmp"
        mv "$tmp" "$config"
      else
        rm -f "$tmp"
        echo "lemond: $config is unreadable, leaving it untouched" >&2
      fi
    '';
  };
in
{
  options.hardware.amd-npu = {
    enable = mkEnableOption "AMD NPU (AI Engine) support";

    xrtPackage = mkOption {
      type = types.package;
      default = extraPkgs.xrt;
      defaultText = lib.literalExpression "pkgs.xrt";
      description = "XRT (Xilinx Runtime) package used for the NPU.";
    };

    xrtPluginPackage = mkOption {
      type = types.package;
      default = extraPkgs.xrt-plugin-amdxdna;
      defaultText = lib.literalExpression "pkgs.xrt-plugin-amdxdna";
      description = ''
        XRT driver plugin for the amdxdna kernel driver. Must be built against
        the same XRT as `xrtPackage`.
      '';
    };

    fastflowlmPackage = mkOption {
      type = types.package;
      default = extraPkgs.fastflowlm;
      defaultText = lib.literalExpression "pkgs.fastflowlm";
      description = "FastFlowLM package installed when `enableFastFlowLM` is set.";
    };

    vllmPackage = mkOption {
      type = types.package;
      default = extraPkgs.vllm-rocm.override { gpuTarget = cfg.vllmGpuTarget; };
      defaultText = lib.literalExpression "pkgs.vllm-rocm.override { gpuTarget = config.hardware.amd-npu.vllmGpuTarget; }";
      description = "vLLM ROCm package that lemonade runs when `enableVllm` is set.";
    };

    enableNPU = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to wire the XDNA-2 NPU stack (amdxdna kernel module, XRT).
        Set false for GPU-only hosts, e.g. RDNA3 iGPUs (Radeon 780M /
        Phoenix / Hawk Point) that lack an XDNA-2 NPU, to keep the
        Vulkan/ROCm backends without pulling in the XRT closure.
      '';
    };

    unlimitedMemlock = mkEnableOption ''
      unlimited locked memory (PAM `memlock`) for every member of the
      `video` and `render` groups, for running FastFlowLM or XRT tools from
      a login session. The lemond and ds4-server units set
      `LimitMEMLOCK=infinity` themselves and do not need this; it raises the
      limit for every user in those groups, so leave it off unless an
      interactive NPU workload fails to pin its buffers'';

    enableFastFlowLM = mkEnableOption "the FastFlowLM NPU inference runtime (requires enableNPU)";

    enableLemonade = mkEnableOption ''
      the Lemonade AI server (`lemond`), a network service listening on
      `lemonade.host`:`lemonade.port`. Also enables nix-ld system-wide
      (overridable via `programs.nix-ld.enable`) so runtime-downloaded omni
      backends (e.g. the kokoro TTS ELF) can find a dynamic loader'';

    enableROCm = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to add ROCm libraries for GPU offload.";
    };

    enableVulkan = mkEnableOption "declarative Vulkan backend wiring for lemonade";

    enableImageGen = mkEnableOption ''
      stable-diffusion.cpp recipes in lemonade (sd-cpp:cpu, plus sd-cpp:rocm
      when enableROCm and sd-cpp:vulkan when enableVulkan). Adds ~150 MB
      CPU-only or ~1.5 GB with ROCm to the closure'';

    enableVllm = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to wire the vLLM ROCm backend (vllm:rocm) into lemonade,
        repackaged from the upstream lemonade-sdk/vllm-rocm prebuilt. Requires
        enableROCm. Experimental, see noamsto/nix-amd-ai#63.
      '';
    };

    gpuTarget = mkOption {
      type = types.enum [
        "gfx1150"
        "gfx1151"
      ];
      default = "gfx1150";
      description = ''
        The host's actual iGPU: gfx1150 (Strix Point) or gfx1151 (Strix
        Halo). Drives the gfx1151 CWSR-kernel warning and the default for
        vllmGpuTarget, so a llamacpp/sd-cpp-only host still declares its
        chip without touching a vLLM option.
      '';
    };

    vllmGpuTarget = mkOption {
      type = types.enum [
        "gfx1150"
        "gfx1151"
      ];
      default = cfg.gpuTarget;
      defaultText = lib.literalExpression "config.hardware.amd-npu.gpuTarget";
      description = ''
        Which lemonade-sdk/vllm-rocm prebuilt to install: gfx1150 (Strix Point)
        or gfx1151 (Strix Halo). Each bundles a TheRock ROCm built for that
        exact target. Defaults to gpuTarget; override only if vLLM needs a
        different target than the host's real chip (e.g. testing). gfx1151
        needs a kernel with the CWSR fix, backported or not, or ROCm can
        crash any ROCm backend, not just vLLM (see the eval-time warning
        this module emits when enableROCm is also set).
      '';
    };

    lemonade = {
      # The Tauri desktop app is the only part needing a Rust and npm build;
      # headless hosts drop it. See noamsto/nix-amd-ai#28.
      package = mkOption {
        type = types.package;
        default = extraPkgs.lemonade-server.override { withDesktopApp = cfg.lemonade.desktopApp.enable; };
        defaultText = lib.literalExpression "pkgs.lemonade-server.override { withDesktopApp = config.hardware.amd-npu.lemonade.desktopApp.enable; }";
        description = ''
          Lemonade server package. It must carry the LEMONADE_DEFAULTS_PATH
          patch that the lemonade-server package applies.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 13305;
        description = "Port for the Lemonade server.";
      };

      host = mkOption {
        type = types.str;
        default = "localhost";
        description = "Host address for the Lemonade server to bind to.";
      };

      user = mkOption {
        type = types.str;
        description = "User account to run the Lemonade server as.";
      };

      desktopApp.enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to build and install the Lemonade desktop app (the Tauri
          shell around the web UI). This is the only part of lemonade that
          requires a Rust + npm build and a crates.io cargo-vendor fetch.
          Set false on headless/server hosts to skip that build path entirely
          and ship only the `lemond` server + CLI.
        '';
      };

      flashAttn = mkOption {
        type = types.enum [
          "auto"
          "on"
          "off"
        ];
        default = "on";
        description = ''
          Value passed as `--flash-attn` to lemond-spawned llama-server. Defaults to "on"
          because upstream lemonade doesn't enable FA for llama-cpp despite enabling it
          for vLLM (see vllm_server.cpp:202); measured ~5% decode / ~10% prefill gain on
          gfx1150 + Gemma. Set "auto" or "off" to override.
        '';
      };

      settings = mkOption {
        inherit ((pkgs.formats.json { })) type;
        default = { };
        example = lib.literalExpression ''
          {
            max_loaded_models = -1;
            auto_evict = true;
          }
        '';
        description = ''
          Extra keys merged into lemond's runtime config, overriding the values
          this module computes. Accepts anything `RuntimeConfig` validates,
          e.g. `max_loaded_models` (-1 for unlimited, so a small NPU model and a
          large GPU model can stay resident together instead of taking turns),
          and `auto_evict` (opt-in idle/VRAM-pressure eviction, off by default)
          with its `auto_evict_threshold_pct`.

          These keys are re-applied on every `lemond` start, so they stay
          declarative; keys not listed here are left to whatever the web UI
          persisted in `''${LEMONADE_CACHE_DIR:-~/.cache/lemonade}/config.json`.
        '';
      };

      allowedOrigins = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "https://app.example.com"
          "http://192.168.1.10:3000"
        ];
        description = ''
          Origins allowed to make cross-origin browser requests, emitted as
          `LEMONADE_ALLOWED_ORIGINS`. Env-only upstream: there is no
          config.json key, so `lemonade.settings` cannot reach it.

          Loopback and non-http(s) desktop schemes (tauri://, file://) are
          always allowed, so this is only needed for browsers on other
          machines reaching a non-loopback `lemonade.host`. `["*"]` allows
          any origin, which without an API key leaves the server open to any
          site the browser visits.
        '';
      };
    };

    ds4 = {
      enable = mkEnableOption "the ds4-server DeepSeek V4 inference server as a systemd unit";

      package = mkOption {
        type = types.package;
        default = extraPkgs.ds4;
        defaultText = lib.literalExpression "pkgs.ds4";
        example = lib.literalExpression ''pkgs.ds4.override { gpuTarget = "gfx1150"; }'';
        description = "ds4 package providing `ds4-server`.";
      };

      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/var/lib/ds4/DeepSeek-V4-Flash.gguf";
        description = ''
          Path to the DeepSeek V4 GGUF served by ds4-server. A runtime path,
          deliberately a string so it is not copied into the Nix store.
          Required when `ds4.enable` is set.
        '';
      };

      ctx = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Allocated context tokens (`--ctx`). null leaves the ds4-server default.";
      };

      host = mkOption {
        type = types.str;
        default = "127.0.0.1";
        description = "Bind address for ds4-server (`--host`).";
      };

      port = mkOption {
        type = types.port;
        default = 8000;
        description = "Bind port for ds4-server (`--port`).";
      };

      user = mkOption {
        type = types.str;
        description = ''
          User account to run ds4-server as. Must be in the `render` and
          `video` groups for ROCm GPU access.
        '';
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "--ssd-streaming"
          "--kv-disk-dir"
          "/var/lib/ds4/server-kv"
        ];
        description = ''
          Extra arguments appended to the ds4-server command line, e.g.
          `--ssd-streaming` with its `--kv-disk-*` flags, or `--threads`. The
          unit provides a writable `/var/lib/ds4` via StateDirectory.
        '';
      };
    };

    gpuMemory = {
      ttmSizeGiB = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = ''
          GTT pool ceiling in GiB, emitted as the `ttm` `pages_limit` modprobe
          option (page count is computed for you: GiB * 262144).

          null (default) leaves the kernel default untouched. No-op on Strix
          Point / 64 GB: the default (~27 GB addressable) already covers
          17-22 GB models. This is the lever a Strix Halo / 128 GB host needs
          to expose its large unified pool. See the "GPU memory headroom"
          section of the noamsto/nix-amd-ai README for recommended Halo
          values.
        '';
      };

      pagePoolSizeGiB = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = ''
          Pre-cached GTT pool size in GiB, emitted as the `ttm` `page_pool_size`
          modprobe option (pages kept warm rather than freed back). Requires
          ttmSizeGiB and must be <= it. null (default) leaves the kernel
          default untouched.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = !cfg.enableNPU || versionAtLeast config.boot.kernelPackages.kernel.version "6.14";
        message = "AMD NPU (amdxdna) requires kernel >= 6.14.";
      }
      {
        assertion = !cfg.enableFastFlowLM || cfg.enableNPU;
        message = "hardware.amd-npu.enableFastFlowLM requires enableNPU = true (FastFlowLM runs on the NPU).";
      }
      {
        assertion = !cfg.enableVllm || (cfg.enableROCm && cfg.enableLemonade);
        message = "hardware.amd-npu.enableVllm requires enableROCm and enableLemonade = true (vLLM runs on the ROCm GPU under lemonade).";
      }
      {
        assertion = cfg.gpuMemory.pagePoolSizeGiB == null || cfg.gpuMemory.ttmSizeGiB != null;
        message = "hardware.amd-npu.gpuMemory.pagePoolSizeGiB requires ttmSizeGiB to be set.";
      }
      {
        assertion = !cfg.ds4.enable || cfg.ds4.model != null;
        message = "hardware.amd-npu.ds4.enable requires hardware.amd-npu.ds4.model (path to a DeepSeek V4 GGUF).";
      }
      {
        assertion =
          cfg.gpuMemory.pagePoolSizeGiB == null
          || cfg.gpuMemory.ttmSizeGiB == null
          || cfg.gpuMemory.pagePoolSizeGiB <= cfg.gpuMemory.ttmSizeGiB;
        message = "hardware.amd-npu.gpuMemory.pagePoolSizeGiB must be <= ttmSizeGiB.";
      }
    ];

    warnings =
      optional
        (
          cfg.enableLemonade
          && cfg.lemonade.allowedOrigins == [ ]
          && !builtins.elem cfg.lemonade.host [
            "localhost"
            "127.0.0.1"
            "::1"
          ]
        )
        "hardware.amd-npu.lemonade.host is non-loopback but lemonade.allowedOrigins is empty; browsers on other machines will get a 403 'Origin not allowed' error. Set lemonade.allowedOrigins to the origins that should reach it."
      # Checks gpuTarget too: the CWSR bug crashes every ROCm backend. A
      # warning, since the fix can be backported.
      ++
        optional
          (
            cfg.enableLemonade
            && cfg.enableROCm
            && (cfg.gpuTarget == "gfx1151" || cfg.vllmGpuTarget == "gfx1151")
            && !versionAtLeast config.boot.kernelPackages.kernel.version "6.18.4"
          )
          "A gfx1151 target is selected (hardware.amd-npu.gpuTarget / vllmGpuTarget), which needs Linux kernel >= 6.18.4 (or the CWSR fix backported) or ROCm can miscalculate VGPR counts and crash llamacpp:rocm, sd-cpp:rocm, and vllm:rocm. Kernel ${config.boot.kernelPackages.kernel.version} is below that; if it carries a backported fix, verify on the host with: grep -E \"cwsr_size|ctl_stack_size\" /sys/class/kfd/kfd/topology/nodes/*/properties";

    boot.kernelModules = optionals cfg.enableNPU [ "amdxdna" ];

    # GTT pool sizing (opt-in): raises what is addressable, not consumed.
    # Needed on Strix Halo / 128 GB for large models.
    boot.extraModprobeConfig = mkIf (cfg.gpuMemory.ttmSizeGiB != null) ''
      options ttm pages_limit=${toString (gttPages cfg.gpuMemory.ttmSizeGiB)}${ttmPagePoolClause}
    '';

    # No udev rule for /dev/accel/accel*: systemd's default rules already
    # set GROUP="render" MODE="0666".

    # Unlimited memlock for NPU buffer allocation from login sessions.
    security.pam.loginLimits = optionals cfg.unlimitedMemlock [
      {
        domain = "@video";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
      {
        domain = "@render";
        type = "-";
        item = "memlock";
        value = "unlimited";
      }
    ];

    environment.sessionVariables =
      optionalAttrs cfg.enableNPU {
        XILINX_XRT = "${xrt-combined}";
        XRT_PATH = "${xrt-combined}";
      }
      // optionalAttrs cfg.enableFastFlowLM {
        # Nix manages the version; skip FLM's update probe (FLM >= 0.9.41).
        FLM_DISABLE_UPDATE_CHECK = "1";
      }
      // optionalAttrs cfg.enableLemonade {
        # Point the lemonade CLI / desktop app at the generated seed (see
        # LEMONADE_DEFAULTS_PATH patch).
        LEMONADE_DEFAULTS_PATH = lemonadeDefaultsFile;
      }
      // optionalAttrs (cfg.enableLemonade && cfg.enableROCm) {
        # Read by is_ggml_hip_plugin_available() (upstream #2044).
        LEMONADE_GGML_HIP_PATH = "${pkgs.llama-cpp-rocm}/lib/libggml-hip.so";
      };

    # Stable indirection symlinks lemonade's config.json bin paths point at.
    environment.etc = lemonadeBackendEtc;

    # The *-cpp engines are deliberately not installed: their ggml .so files
    # in $out/bin get dlopen'd by glib's GIO module loader on every glib app.
    # lemond uses the /etc/lemonade/backends/* symlinks instead.
    environment.systemPackages = [
      pkgs.pciutils
      pkgs.lshw
    ]
    ++ optional cfg.enableNPU xrt-combined
    ++ optional cfg.enableFastFlowLM cfg.fastflowlmPackage
    ++ optional cfg.enableLemonade lemonadePackage
    ++ optional cfg.enableROCm pkgs.rocmPackages.clr;

    # koko (kokoro TTS) is a downloaded prebuilt ELF needing
    # /lib64/ld-linux-x86-64.so.2. mkDefault so hosts can manage nix-ld.
    programs.nix-ld.enable = mkIf cfg.enableLemonade (mkDefault true);

    systemd.services.lemond = mkIf cfg.enableLemonade {
      description = "Lemonade AI Server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = pathList ++ [ "/run/current-system/sw" ];
      environment = {
        # Backend paths, global_timeout and flash-attn live in the generated
        # defaults.json (v10.7.0 dropped their env hooks).
        LEMONADE_DEFAULTS_PATH = lemonadeDefaultsFile;
      }
      // optionalAttrs cfg.enableNPU {
        XILINX_XRT = "${xrt-combined}";
        XRT_PATH = "${xrt-combined}";
      }
      // optionalAttrs (ldLibraryPath != "") {
        LD_LIBRARY_PATH = ldLibraryPath;
      }
      // optionalAttrs cfg.enableROCm {
        LEMONADE_GGML_HIP_PATH = "${pkgs.llama-cpp-rocm}/lib/libggml-hip.so";
      }
      // optionalAttrs cfg.enableFastFlowLM {
        # See FLM_DISABLE_UPDATE_CHECK above.
        FLM_DISABLE_UPDATE_CHECK = "1";
      }
      // optionalAttrs config.programs.nix-ld.enable {
        # nix-ld exports these only as session vars; re-export for the unit.
        NIX_LD = config.environment.sessionVariables.NIX_LD;
        NIX_LD_LIBRARY_PATH = config.environment.sessionVariables.NIX_LD_LIBRARY_PATH;
      }
      // optionalAttrs (cfg.lemonade.allowedOrigins != [ ]) {
        # Env-only in lemonade >= 11.5.0 (no config.json key).
        LEMONADE_ALLOWED_ORIGINS = concatStringsSep "," cfg.lemonade.allowedOrigins;
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.lemonade.user;
        # GPU (/dev/kfd, /dev/dri/renderD*) and NPU (/dev/accel) access.
        SupplementaryGroups = [
          "render"
          "video"
        ];
        ExecStartPre = "${lemonadeReconcile}/bin/lemond-reconcile-config";
        ExecStart = utils.escapeSystemdExecArgs [
          "${lemonadePackage}/bin/lemond"
          "--port"
          cfg.lemonade.port
          "--host"
          cfg.lemonade.host
        ];
        Restart = "on-failure";
        RestartSec = "5s";
        KillSignal = "SIGINT";
        LimitMEMLOCK = "infinity";
        # WhisperServer resolves its writable runtime dir from RUNTIME_DIRECTORY.
        RuntimeDirectory = "lemond";
      };
    };

    # ds4-server: OpenAI-compatible DeepSeek V4 server. Its rpath covers the
    # ROCm libs, so it only needs GPU device access and a state dir for the
    # optional KV cache.
    systemd.services.ds4-server = mkIf cfg.ds4.enable {
      description = "ds4 DeepSeek V4 inference server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "simple";
        User = cfg.ds4.user;
        SupplementaryGroups = [
          "video"
          "render"
        ];
        # Quote each argument so spaces, `%` and `$` pass through unchanged.
        ExecStart = utils.escapeSystemdExecArgs (
          [
            "${cfg.ds4.package}/bin/ds4-server"
            "--model"
            cfg.ds4.model
            "--host"
            cfg.ds4.host
            "--port"
            cfg.ds4.port
          ]
          ++ optionals (cfg.ds4.ctx != null) [
            "--ctx"
            cfg.ds4.ctx
          ]
          ++ cfg.ds4.extraArgs
        );
        Restart = "on-failure";
        RestartSec = "5s";
        KillSignal = "SIGINT";
        LimitMEMLOCK = "infinity";
        StateDirectory = "ds4";
      };
    };
  };
}
