## boot\.fallbackBoot\.enable



Whether to enable automatic revert to the last known-good NixOS generation on a failed or unhealthy boot (GRUB mirrored-boot machines)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/boot-fallback>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/boot-fallback)



## boot\.fallbackBoot\.criticalUnits

Units that must be ` active ` for a boot to count as healthy\. List only
long-running daemons whose ` systemctl is-active ` is reliably ` active `;
do NOT list socket-activated units (they report ` inactive ` when idle and
would trigger a false revert)\. An empty list disables health-based
revert but keeps boot-failure revert via the armed flag\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "sshd.service"
  "postgresql.service"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/boot-fallback>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/boot-fallback)



## boot\.fallbackBoot\.settleSeconds



Seconds to wait for the critical units to become active before treating
the boot as unhealthy and reverting\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
90
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/boot-fallback>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/boot-fallback)



## hardware\.amd-npu\.enable



Whether to enable AMD NPU (AI Engine) support\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableFastFlowLM



Whether to enable the FastFlowLM NPU inference runtime (requires enableNPU)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableImageGen



Whether to enable stable-diffusion\.cpp recipes in lemonade (sd-cpp:cpu, plus sd-cpp:rocm
when enableROCm and sd-cpp:vulkan when enableVulkan)\. Adds ~150 MB
CPU-only or ~1\.5 GB with ROCm to the closure\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableLemonade



Whether to enable the Lemonade AI server (` lemond `), a network service listening on
` lemonade.host `:` lemonade.port `\. Also enables nix-ld system-wide
(overridable via ` programs.nix-ld.enable `) so runtime-downloaded omni
backends (e\.g\. the kokoro TTS ELF) can find a dynamic loader\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableNPU



Whether to wire the XDNA-2 NPU stack (amdxdna kernel module, XRT)\.
Set false for GPU-only hosts, e\.g\. RDNA3 iGPUs (Radeon 780M /
Phoenix / Hawk Point) that lack an XDNA-2 NPU, to keep the
Vulkan/ROCm backends without pulling in the XRT closure\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableROCm



Whether to add ROCm libraries for GPU offload\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableVllm



Whether to wire the vLLM ROCm backend (vllm:rocm) into lemonade,
repackaged from the upstream lemonade-sdk/vllm-rocm prebuilt\. Requires
enableROCm\. Experimental, see noamsto/nix-amd-ai\#63\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.enableVulkan



Whether to enable declarative Vulkan backend wiring for lemonade\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.enable



Whether to enable the ds4-server DeepSeek V4 inference server as a systemd unit\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.package



ds4 package providing ` ds4-server `\.



*Type:*
package



*Default:*

```nix
pkgs.ds4
```



*Example:*

```nix
pkgs.ds4.override { gpuTarget = "gfx1150"; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.ctx



Allocated context tokens (` --ctx `)\. null leaves the ds4-server default\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.extraArgs



Extra arguments appended to the ds4-server command line, e\.g\.
` --ssd-streaming ` with its ` --kv-disk-* ` flags, or ` --threads `\. The
unit provides a writable ` /var/lib/ds4 ` via StateDirectory\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "--ssd-streaming"
  "--kv-disk-dir"
  "/var/lib/ds4/server-kv"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.host



Bind address for ds4-server (` --host `)\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.model



Path to the DeepSeek V4 GGUF served by ds4-server\. A runtime path,
deliberately a string so it is not copied into the Nix store\.
Required when ` ds4.enable ` is set\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"/var/lib/ds4/DeepSeek-V4-Flash.gguf"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.port



Bind port for ds4-server (` --port `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8000
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.ds4\.user



User account to run ds4-server as\. Must be in the ` render ` and
` video ` groups for ROCm GPU access\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.fastflowlmPackage



FastFlowLM package installed when ` enableFastFlowLM ` is set\.



*Type:*
package



*Default:*

```nix
pkgs.fastflowlm
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.gpuMemory\.pagePoolSizeGiB



Pre-cached GTT pool size in GiB, emitted as the ` ttm ` ` page_pool_size `
modprobe option (pages kept warm rather than freed back)\. Requires
ttmSizeGiB and must be \<= it\. null (default) leaves the kernel
default untouched\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.gpuMemory\.ttmSizeGiB



GTT pool ceiling in GiB, emitted as the ` ttm ` ` pages_limit ` modprobe
option (page count is computed for you: GiB \* 262144)\.

null (default) leaves the kernel default untouched\. No-op on Strix
Point / 64 GB: the default (~27 GB addressable) already covers
17-22 GB models\. This is the lever a Strix Halo / 128 GB host needs
to expose its large unified pool\. See the “GPU memory headroom”
section of the noamsto/nix-amd-ai README for recommended Halo
values\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.gpuTarget



The host’s actual iGPU: gfx1150 (Strix Point) or gfx1151 (Strix
Halo)\. Drives the gfx1151 CWSR-kernel warning and the default for
vllmGpuTarget, so a llamacpp/sd-cpp-only host still declares its
chip without touching a vLLM option\.



*Type:*
one of “gfx1150”, “gfx1151”



*Default:*

```nix
"gfx1150"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.package



Lemonade server package\. It must carry the LEMONADE_DEFAULTS_PATH
patch that the lemonade-server package applies\.



*Type:*
package



*Default:*

```nix
pkgs.lemonade-server.override { withDesktopApp = config.hardware.amd-npu.lemonade.desktopApp.enable; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.allowedOrigins



Origins allowed to make cross-origin browser requests, emitted as
` LEMONADE_ALLOWED_ORIGINS `\. Env-only upstream: there is no
config\.json key, so ` lemonade.settings ` cannot reach it\.

Loopback and non-http(s) desktop schemes (tauri://, file://) are
always allowed, so this is only needed for browsers on other
machines reaching a non-loopback ` lemonade.host `\. ` ["*"] ` allows
any origin, which without an API key leaves the server open to any
site the browser visits\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "https://app.example.com"
  "http://192.168.1.10:3000"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.desktopApp\.enable



Whether to build and install the Lemonade desktop app (the Tauri
shell around the web UI)\. This is the only part of lemonade that
requires a Rust + npm build and a crates\.io cargo-vendor fetch\.
Set false on headless/server hosts to skip that build path entirely
and ship only the ` lemond ` server + CLI\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.flashAttn



Value passed as ` --flash-attn ` to lemond-spawned llama-server\. Defaults to “on”
because upstream lemonade doesn’t enable FA for llama-cpp despite enabling it
for vLLM (see vllm_server\.cpp:202); measured ~5% decode / ~10% prefill gain on
gfx1150 + Gemma\. Set “auto” or “off” to override\.



*Type:*
one of “auto”, “on”, “off”



*Default:*

```nix
"on"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.host



Host address for the Lemonade server to bind to\.



*Type:*
string



*Default:*

```nix
"localhost"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.port



Port for the Lemonade server\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
13305
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.settings



Extra keys merged into lemond’s runtime config, overriding the values
this module computes\. Accepts anything ` RuntimeConfig ` validates,
e\.g\. ` max_loaded_models ` (-1 for unlimited, so a small NPU model and a
large GPU model can stay resident together instead of taking turns),
and ` auto_evict ` (opt-in idle/VRAM-pressure eviction, off by default)
with its ` auto_evict_threshold_pct `\.

These keys are re-applied on every ` lemond ` start, so they stay
declarative; keys not listed here are left to whatever the web UI
persisted in ` ${LEMONADE_CACHE_DIR:-~/.cache/lemonade}/config.json `\.



*Type:*
JSON value



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  max_loaded_models = -1;
  auto_evict = true;
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.lemonade\.user



User account to run the Lemonade server as\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.unlimitedMemlock



Whether to enable unlimited locked memory (PAM ` memlock `) for every member of the
` video ` and ` render ` groups, for running FastFlowLM or XRT tools from
a login session\. The lemond and ds4-server units set
` LimitMEMLOCK=infinity ` themselves and do not need this; it raises the
limit for every user in those groups, so leave it off unless an
interactive NPU workload fails to pin its buffers\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.vllmGpuTarget



Which lemonade-sdk/vllm-rocm prebuilt to install: gfx1150 (Strix Point)
or gfx1151 (Strix Halo)\. Each bundles a TheRock ROCm built for that
exact target\. Defaults to gpuTarget; override only if vLLM needs a
different target than the host’s real chip (e\.g\. testing)\. gfx1151
needs a kernel with the CWSR fix, backported or not, or ROCm can
crash any ROCm backend, not just vLLM (see the eval-time warning
this module emits when enableROCm is also set)\.



*Type:*
one of “gfx1150”, “gfx1151”



*Default:*

```nix
config.hardware.amd-npu.gpuTarget
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.vllmPackage



vLLM ROCm package that lemonade runs when ` enableVllm ` is set\.



*Type:*
package



*Default:*

```nix
pkgs.vllm-rocm.override { gpuTarget = config.hardware.amd-npu.vllmGpuTarget; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.xrtPackage



XRT (Xilinx Runtime) package used for the NPU\.



*Type:*
package



*Default:*

```nix
pkgs.xrt
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## hardware\.amd-npu\.xrtPluginPackage



XRT driver plugin for the amdxdna kernel driver\. Must be built against
the same XRT as ` xrtPackage `\.



*Type:*
package



*Default:*

```nix
pkgs.xrt-plugin-amdxdna
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/amd-npu>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/amd-npu)



## programs\.nix-ccache\.enable



Whether to enable the nix-ccache ELF shim for sandboxed Nix builds\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nix-ccache>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nix-ccache)



## programs\.nix-ccache\.package



The nix-ccache shim to install\. It has its cache directory compiled
in, so the default follows ` programs.ccache.cacheDir `; a custom
package must be built with the same directory\.



*Type:*
package



*Default:*

```nix
pkgs.nix-ccache.override { cacheDir = config.programs.ccache.cacheDir; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nix-ccache>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nix-ccache)



## security\.u2fKey\.enable



Whether to enable U2F hardware key as an alternative authentication factor\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/u2f>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/u2f)



## security\.u2fKey\.services



PAM services where a U2F touch is accepted in place of the password\.
Excludes greetd, login and sshd: under “sufficient” a touch alone
would open a fresh session or a remote login\.



*Type:*
list of string



*Default:*

```nix
[
  "sudo"
  "hyprlock"
  "swaylock"
  "polkit-1"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/u2f>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/u2f)



## security\.workstationHardening\.enable



Whether to enable low-cost hardening for single-user workstations\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.audit



Enable auditd with rules for identity, kernel-module changes and for
what a logged-in user runs as root\. Nix daemon builds have no login uid,
so the auid filter keeps them out\. The failure mode stays printk: a full
backlog never panics the machine\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.auditWatchPaths



Extra paths to watch for writes and attribute changes, each reported
under the ` watch ` audit key\. Only used when ` audit ` is on\.



*Type:*
list of absolute path



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "/etc/ssh/sshd_config"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.blacklistProtocols



Refuse the network protocols listed in ` protocols `, each a past
source of kernel CVEs reachable through an unprivileged socket()
autoload\. An ` install ` line also refuses an explicit modprobe, which a
blacklist entry does not\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.dockerLoopback



Make Docker publish ` -p ` ports on 127\.0\.0\.1 by default\. Published ports
are DNATed through FORWARD and never reach the nixos-fw INPUT chain, so
the daemon’s default bind address is what keeps them off the network\.
` -p 0.0.0.0:X:Y ` still opens a port on purpose\. No effect while Docker
is off\. Rootless Podman publishes through the user’s slirp4netns or
pasta and is not covered: bind each Podman or oci-containers port to
127\.0\.0\.1 explicitly\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.firewall



Assert the host firewall on explicitly, so the deny-inbound policy holds
regardless of upstream default changes\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.noCoreDumps



Disable core dumps, which can hold keys and tokens: systemd-coredump
stores nothing and the hard core limit is zero, so dumps that never
reach systemd-coredump are stopped too\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.processAccounting



Enable BSD process accounting (` lastcomm `, ` sa `)\. logrotate cannot rotate
the pacct file: it lacks CAP_SYS_PACCT and its syscall filter blocks
acct(2)\. A daily ` acct-rotate ` timer rotates it and re-arms accton on
the new file\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.protocols



Kernel modules refused when ` blacklistProtocols ` is on\.



*Type:*
list of string



*Default:*

```nix
[
  "dccp"
  "sctp"
  "rds"
  "tipc"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## security\.workstationHardening\.sysctl



Set the Lynis KRNL-6000 sysctls that cost nothing on a workstation\.
` fs.suid_dumpable ` overrides systemd’s 50-coredump\.conf, since
60-nixos\.conf sorts later\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/workstation-hardening>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/workstation-hardening)



## services\.backupFreshness\.enable



Whether to enable a periodic check that every backup job ran and succeeded recently\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.borgbackup



Check every scheduled job in ` services.borgbackup.jobs `\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.dailyMaxAgeDays



Days since the last run after which a job not scheduled ` weekly ` counts as stale\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
2
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.extraUnits



Other oneshot backup units to check, by unit name\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  "my-backup.service" = {
    maxAgeDays = 7;
  };
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.extraUnits\.\<name>\.maxAgeDays



Days since the last run after which the unit counts as stale\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
2
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.onCalendar



When to run the check ([` systemd.time(7) `](https://www.freedesktop.org/software/systemd/man/systemd.time.html))\. Keep it clear of the
backup window itself (jobs plus any RandomizedDelaySec)\.



*Type:*
string



*Default:*

```nix
"*-*-* 07:00:00"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.restic



Check every scheduled backup in ` services.restic.backups `\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.backupFreshness\.weeklyMaxAgeDays



Days since the last run after which a job scheduled ` weekly ` counts as stale\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
10
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/backup-freshness>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/backup-freshness)



## services\.expose\.cloudflare\.enable



Whether to enable publishing services\.expose entries through a Cloudflare Tunnel\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.cloudflare\.baseDomain



Domain an entry’s ` cloudflare.subdomain ` is put under\. May stay
null when every entry sets ` cloudflare.hostname `\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"apps.example.com"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.cloudflare\.credentialsFile



The tunnel’s credentials JSON, read at run time\. Keep it out of the
Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/credentials/cloudflared-tunnel.json"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.cloudflare\.default



Service for requests that match no ingress rule\.



*Type:*
string



*Default:*

```nix
"http_status:404"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.cloudflare\.tunnelId



UUID of the tunnel (` cloudflared tunnel create ` prints it)\. Names
the ` services.cloudflared.tunnels ` entry this backend fills, so its
other settings can be set there\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"00000000-0000-0000-0000-000000000000"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.landing\.enable



Whether to enable a landing page listing the services\.expose entries\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/landing\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/landing.nix)



## services\.expose\.landing\.port



Loopback port the page is served on\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8780
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/landing\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/landing.nix)



## services\.expose\.landing\.register



Add the page itself as ` services.expose.services.landing `, so the
enabled backends publish it: on port 443 of this node for Tailscale,
and at the tunnel’s base domain if ` cloudflare.enable ` is set on the
entry\. Its options can be changed there like any other entry’s\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/landing\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/landing.nix)



## services\.expose\.landing\.title



Page heading\.



*Type:*
string



*Default:*

```nix
config.networking.hostName
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/landing\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/landing.nix)



## services\.expose\.localWeb\.enable



Whether to enable serving services\.expose entries as ` <name>.localhost ` sites\. Needs the
local-web module, and enables services\.localWeb\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/local-web\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/local-web.nix)



## services\.expose\.services



Local services to publish\. Each entry is inert until a backend
(` services.expose.tailscale `, ` .cloudflare `, ` .localWeb `, ` .landing `)
is enabled\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  jellyfin = {
    title = "Jellyfin";
    upstream = "http://127.0.0.1:8096";
    tailscale.service = "jellyfin";
  };
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/local-web\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/local-web.nix)
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.enable



Whether backends publish this entry\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.cloudflare\.enable



Publish this entry through the tunnel, once
` services.expose.cloudflare.enable ` is set\. Off by default:
this is the public edge\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.services\.\<name>\.cloudflare\.access



Whether a Cloudflare Access application is expected in front
of the hostname\. Only records intent (Access is configured on
the Cloudflare side); false makes the build warn that the
hostname is public\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.services\.\<name>\.cloudflare\.hostname



Full hostname, instead of ` subdomain ` under the base domain\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"status.example.org"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.services\.\<name>\.cloudflare\.subdomain



Label under ` services.expose.cloudflare.baseDomain `; the empty
string publishes at the base domain itself\.



*Type:*
string



*Default:*

```nix
<name>
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/cloudflare\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/cloudflare.nix)



## services\.expose\.services\.\<name>\.description



One line shown next to the title\.



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.localWeb\.enable



Serve this entry as ` http://<name>.localhost `, once
` services.expose.localWeb.enable ` is set\.



*Type:*
boolean



*Default:*
whether ` upstream ` is an ` http:// ` or ` https:// ` URL

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/local-web\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/local-web.nix)



## services\.expose\.services\.\<name>\.order



Position on the landing page (then by name)\.



*Type:*
signed integer



*Default:*

```nix
100
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.path



Path appended to the published URLs in ` urls `, for a UI that
lives below the root\. Routing is unchanged: the whole host
still forwards to ` upstream `\.



*Type:*
string



*Default:*

```nix
"/"
```



*Example:*

```nix
"/ui/"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.tailscale\.enable



Whether the Tailscale backend publishes this entry, once
` services.expose.tailscale.enable ` is set\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.services\.\<name>\.tailscale\.funnel



Publish on the public internet with Tailscale Funnel instead
of the tailnet only\. The tailnet policy must allow funnel
for this node\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.services\.\<name>\.tailscale\.port



Port the entry listens on: on this node’s tailnet address,
or on the Tailscale Service’s own address when ` service ` is
set\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
443
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.services\.\<name>\.tailscale\.protocol



Listener protocol\. ` https ` terminates TLS with the tailnet
certificate; ` tcp ` forwards raw TCP\.



*Type:*
one of “https”, “http”, “tcp”



*Default:*

```nix
"https"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.services\.\<name>\.tailscale\.service



Publish as the Tailscale Service ` svc:<service> ` instead of
on a port of this node\. The node must be tagged, and the
tailnet policy must let it host the service (or approve it
automatically)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"jellyfin"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.services\.\<name>\.title



Human-readable name, shown on the landing page\.



*Type:*
string



*Default:*

```nix
<name>
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.upstream



URL the backends forward to, usually a loopback address
(` http://127.0.0.1:PORT `, or ` tcp://127.0.0.1:PORT ` for a raw
TCP service)\.



*Type:*
string



*Example:*

```nix
"http://127.0.0.1:8096"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.services\.\<name>\.urls



URLs the enabled backends publish this entry at, keyed by
backend (` tailscale `, ` cloudflare `, ` localWeb `)\. Filled in by
the backends; read it, don’t set it\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose)



## services\.expose\.tailscale\.enable



Whether to enable publishing services\.expose entries with tailscale serve\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.tailscale\.domain



The tailnet’s MagicDNS suffix\. Only used to fill in ` urls ` (and so
the landing page); null leaves the tailnet URLs out\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"tail0123.example"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.expose\.tailscale\.nodeName



This node’s MagicDNS name, for the URLs of node-port entries\.



*Type:*
string



*Default:*

```nix
config.networking.hostName
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/expose/tailscale\.nix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/expose/tailscale.nix)



## services\.grafanaCloud\.enable



Whether to enable shipping telemetry to Grafana Cloud via Grafana Alloy\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.package



Grafana Alloy package to run\.



*Type:*
package



*Default:*

```nix
pkgs.grafana-alloy
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.environment



Value for an ` env ` external label\. No label is added when null\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"prod"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.environmentFile



Path to a systemd EnvironmentFile that defines ` GC_TOKEN `, a
Grafana Cloud Access Policy token valid for every enabled signal\.
Required when the module is enabled\. The file is read at run time
and never copied to the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/secrets/grafana-cloud.env"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.externalLabels



Extra external labels attached to every signal\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.extraConfig



Extra Alloy (River) configuration appended verbatim\.



*Type:*
strings concatenated with “\\n”



*Default:*

```nix
""
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.enable



Send logs to Grafana Cloud Loki\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.endpoint



Loki push endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://logs-prod-012.grafana.net/loki/api/v1/push"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.files



Log files to tail\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.files\.\*\.labels



Additional labels\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.files\.\*\.path



Glob path to tail\.



*Type:*
string



*Example:*

```nix
"/var/log/*.log"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.journal



Forward systemd journal entries\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.logs\.user

Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.enable



Send metrics to Grafana Cloud Prometheus\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.endpoint



Prometheus remote_write endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://prometheus-prod-01-eu-west-0.grafana.net/api/prom/push"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets



Additional static scrape targets\.



*Type:*
list of (submodule)



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.address



host:port of the scrape target\.



*Type:*
string



*Example:*

```nix
"127.0.0.1:9100"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.job



Prometheus ` job ` label\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.extraScrapeTargets\.\*\.labels



Additional labels\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.nodeExporter



Enable the built-in ` prometheus.exporter.unix ` (node exporter)\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.nodeExporterCollectors



Collectors enabled on ` prometheus.exporter.unix `\.



*Type:*
list of string



*Default:*

```nix
[
  "cpu"
  "diskstats"
  "filesystem"
  "loadavg"
  "meminfo"
  "netdev"
  "netstat"
  "stat"
  "time"
  "uname"
  "vmstat"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.scrapeInterval



Scrape interval for the built-in scrape jobs\.



*Type:*
string



*Default:*

```nix
"60s"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.enable



Run the smartctl exporter and scrape it for SMART attributes\.
Honoured by the NixOS module only\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.devices



Devices to monitor\. Empty means autodiscover\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "/dev/sda"
  "/dev/nvme0n1"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.listenAddress



Listen address of the smartctl exporter\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.maxInterval



Minimum interval between SMART queries per disk\.



*Type:*
string



*Default:*

```nix
"60s"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.smartctl\.port



TCP port of the smartctl exporter\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
9633
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.metrics\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.profiles\.enable



Send continuous profiling data to Grafana Cloud Profiles\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.profiles\.endpoint



Pyroscope push endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://profiles-prod-001.grafana.net"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.profiles\.selfScrape



Scrape Alloy’s own pprof endpoints\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.profiles\.selfScrapeAddress



Address of Alloy’s HTTP server, scraped when ` selfScrape ` is set\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:12345"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.profiles\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.traces\.enable



Expose OTLP receivers and forward traces to Grafana Cloud Tempo\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.traces\.endpoint



OTLP HTTP endpoint URL of the Grafana Cloud stack\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"https://otlp-gateway-prod-eu-west-0.grafana.net/otlp"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.traces\.otlpGrpcListen



Listen address of the OTLP gRPC receiver\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:4317"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.traces\.otlpHttpListen



Listen address of the OTLP HTTP receiver\.



*Type:*
string



*Default:*

```nix
"127.0.0.1:4318"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.grafanaCloud\.traces\.user



Basic-auth username (the instance ID of this signal in the stack)\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"1234567"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/grafana-cloud>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/grafana-cloud)



## services\.langfuse\.enable



Whether to enable self-hosted Langfuse with native backing services\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.package



The Langfuse package to run\.



*Type:*
package



*Default:*

```nix
pkgs.langfuse
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.clickhouseMaxMemory



ClickHouse ` max_server_memory_usage ` in bytes\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
4294967296
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.createLocally



Enable services\.postgresql on this host and create the database
and its owner, reached over the Unix socket with peer
authentication\. Requires ` database.name ` and ` database.user ` to
be ` langfuse `, the service user\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.host



PostgreSQL host name, or a Unix socket directory when it starts
with ` / `\.



*Type:*
string



*Default:*

```nix
"/run/postgresql"
```



*Example:*

```nix
"db.example.org"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.name



PostgreSQL database name\.



*Type:*
string



*Default:*

```nix
"langfuse"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.passwordFile



File holding the PostgreSQL password, passed to the services as a
systemd credential\. Null connects without a password (peer or
trust authentication)\. A ` DATABASE_URL ` in
` services.langfuse.environmentFile ` replaces the URL built
from these options\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/keys/langfuse-db-password"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.port



PostgreSQL port (also selects the socket file for a socket ` host `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
5432
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.database\.user



PostgreSQL role Langfuse connects as\.



*Type:*
string



*Default:*

```nix
"langfuse"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.environmentFile



Extra environment file for web, worker and migrations; overrides generated values\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.ingestEnvFile



Root-only ` LANGFUSE_PUBLIC_KEY `/` LANGFUSE_SECRET_KEY `/` LANGFUSE_HOST ` for a
systemd ` EnvironmentFile= ` of a service that sends to the initial project\.



*Type:*
absolute path *(read only)*



*Default:*

```nix
"/var/lib/langfuse-secrets/ingest.env"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.ingestHeadersFile



OTLP ingest headers file, readable by ` services.langfuse.ingestUsers `\.



*Type:*
absolute path *(read only)*



*Default:*

```nix
"/var/lib/langfuse-ingest/otlp-headers.json"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.ingestKeyFiles



Key files (` public `, ` secret `) readable by ` services.langfuse.ingestUsers `\.



*Type:*
attribute set of absolute path *(read only)*



*Default:*

```nix
{
  public = "/var/lib/langfuse-ingest/public-key";
  secret = "/var/lib/langfuse-ingest/secret-key";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.ingestUsers



Users allowed to read the OTLP ingest credentials of the initial project:
` {"Authorization": "Basic ..."} ` as JSON from ` services.langfuse.ingestHeadersFile `,
and the bare key pair from ` services.langfuse.ingestKeyFiles `\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "alice"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections



LLM connections of the initial project, keyed by provider name and
upserted through the public API after every start of the web service\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections\.\<name>\.adapter



LLM adapter (` openai ` covers any OpenAI-compatible server)\.



*Type:*
string



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections\.\<name>\.baseURL



API base URL; its host is added to the base-URL whitelist\.



*Type:*
string



*Example:*

```nix
"http://127.0.0.1:8080/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections\.\<name>\.models



Custom model names offered in the playground and evals\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections\.\<name>\.secretKeyFile



File holding the API key sent to the server, passed to the
upsert unit as a systemd credential\. Null sends ` none `, for
keyless local servers (the API requires a non-empty value)\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/keys/openai-api-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.llmConnections\.\<name>\.withDefaultModels



Also offer the adapter’s built-in model list\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.port



Loopback port of the web UI and public API (OTLP at /api/public/otel)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
3000
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.publicKey



Public API key of the initial project; the secret key is generated\.



*Type:*
string



*Default:*

```nix
"pk-lf-local"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.retentionDays



Delete traces, observations, scores and media older than this many
days, via the worker’s batch retention cleaner\. Applied to every
project\. Null keeps everything\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```



*Example:*

```nix
90
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.secretFiles\.encryptionKey



File holding ENCRYPTION_KEY (64 hex characters), read at run time by root\. Null generates one on
first start and keeps it under /var/lib/langfuse-secrets\. A missing, unreadable
or empty file fails ` langfuse-secrets.service `, and with it Langfuse,
rather than falling back to a generated value\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.secretFiles\.initialUserPassword



File holding the initial user’s password, read at run time by root\. Null generates one on
first start and keeps it under /var/lib/langfuse-secrets\. A missing, unreadable
or empty file fails ` langfuse-secrets.service `, and with it Langfuse,
rather than falling back to a generated value\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.secretFiles\.nextauthSecret



File holding NEXTAUTH_SECRET, read at run time by root\. Null generates one on
first start and keeps it under /var/lib/langfuse-secrets\. A missing, unreadable
or empty file fails ` langfuse-secrets.service `, and with it Langfuse,
rather than falling back to a generated value\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.secretFiles\.projectSecretKey



File holding the initial project’s secret key, without the ` sk-lf- ` prefix, read at run time by root\. Null generates one on
first start and keeps it under /var/lib/langfuse-secrets\. A missing, unreadable
or empty file fails ` langfuse-secrets.service `, and with it Langfuse,
rather than falling back to a generated value\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.secretFiles\.salt



File holding the API key hashing SALT, read at run time by root\. Null generates one on
first start and keeps it under /var/lib/langfuse-secrets\. A missing, unreadable
or empty file fails ` langfuse-secrets.service `, and with it Langfuse,
rather than falling back to a generated value\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.shareBackends



Allow other modules to configure services\.clickhouse and
services\.garage as well\. Langfuse treats both as its own: ClickHouse
runs in UTC, capped at ` services.langfuse.clickhouseMaxMemory `,
with most system log tables removed, and Langfuse’s tables (and
golang-migrate’s ` schema_migrations `) in the ` default ` database;
Garage is a single loopback-only node on ports 3900/3901 with
` replication_factor = 1 `, Langfuse’s generated RPC secret and a
layout assigned on first start\. Another user of either service
silently gets all of this, so by default evaluation fails when a
module outside this one sets their options\. Set this after checking
that the other user (Plausible, for example, enables ClickHouse) can
live with it\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.smtp\.connectionUrl



SMTP_CONNECTION_URL for outgoing mail (invitations, password
reset, email login)\. Null keeps mail sending unconfigured\. Put a
URL carrying credentials in
` services.langfuse.environmentFile ` instead\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"smtp://127.0.0.1:25"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.smtp\.fromAddress



EMAIL_FROM_ADDRESS for outgoing mail; pair with smtp\.connectionUrl\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"langfuse@example.org"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.url



URL the browser reaches the web UI at (NEXTAUTH_URL)\.



*Type:*
string



*Default:*

```nix
"http://localhost:${toString config.services.langfuse.port}"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.userEmail



Login of the initial (and only) user, created on first start\.



*Type:*
string



*Default:*

```nix
"admin@langfuse.local"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.langfuse\.userName



Display name of the initial user\.



*Type:*
string



*Default:*

```nix
"Admin"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/langfuse>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/langfuse)



## services\.lazylibrarian\.enable



Whether to enable LazyLibrarian, an ebook, audiobook and magazine downloader\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.package



The LazyLibrarian package to run\.



*Type:*
package



*Default:*

```nix
pkgs.lazylibrarian
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.dataDir



Directory for the database, config\.ini, cache and logs\.



*Type:*
absolute path



*Default:*

```nix
"/var/lib/lazylibrarian"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.extraArgs



Extra command-line arguments for LazyLibrarian\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "--loglevel"
  "2"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.group



Group the service runs as\. Created only when left at the default\.



*Type:*
string



*Default:*

```nix
"lazylibrarian"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.openFirewall



Open ` port ` in the host firewall\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.port



Port of the web UI\. Overrides the port saved in config\.ini\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
5299
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.lazylibrarian\.user



User the service runs as\. Created only when left at the default\.



*Type:*
string



*Default:*

```nix
"lazylibrarian"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/lazylibrarian>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/lazylibrarian)



## services\.localLlm\.enable



Whether to enable a local OpenAI-compatible model stack (llama-swap with chat, embedding and rerank servers)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.package

The llama-cpp package to use\. The llama\.cpp build providing llama-server; pick the GPU backend per host\.



*Type:*
package



*Default:*

```nix
pkgs.llama-cpp
```



*Example:*

```nix
llama-cpp-vulkan
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.cacheRam



Host-RAM prompt cache in MiB (` --cache-ram `); 0 disables it\. It lets
a request reuse the KV of an earlier prompt with the same prefix\.
llama-server’s own default is 8192\.



*Type:*
unsigned integer, meaning >=0



*Default:*

```nix
2048
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.concurrencyLimit



In-flight requests llama-swap accepts before answering 429 (its
own default is 10)\. Requests past the ` parallel ` slots wait in
llama-server’s queue, so a lower limit fails fast instead\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
64
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.contextSize



Total context (` -c `), shared across the ` parallel ` slots\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
32768
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.extraArgs



Extra llama-server arguments after the generated ones\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "--chat-template-kwargs '{\"enable_thinking\":false}'"
  "--temp 0.7"
  "--top-p 0.8"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.mlock



Lock the mmapped weights in RAM (` --mlock `), so memory pressure
cannot evict them\. Pins the whole model while it is loaded\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.mmproj



Vision projector GGUF (` --mmproj `); null serves text only\.



*Type:*
null or package or string



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.mmprojOffload



Keep the vision projector on the GPU\. When false, image encoding runs on the CPU\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.model



GGUF weights of the chat model: a fetched store path or a path
outside the store\. Null leaves the role unserved\.



*Type:*
null or package or string



*Default:*

```nix
null
```



*Example:*

```nix
pkgs.fetchurl {
  url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
  hash = "sha256-...";
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.nCpuMoe



Layers of a MoE model whose expert weights stay in system RAM
(` --n-cpu-moe `), the knob for fitting VRAM: attention, shared
weights and KV cache stay on the GPU\. Lower values put more on the
GPU (faster, more VRAM)\.



*Type:*
null or (unsigned integer, meaning >=0)



*Default:*

```nix
null
```



*Example:*

```nix
40
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.name



Model id clients send in the ` model ` field\.



*Type:*
string



*Default:*

```nix
"chat"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.parallel



Concurrent request slots (` -np `)\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
2
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.threads



CPU threads (` -t `); null keeps llama-server’s default\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.ttl



Seconds of inactivity before llama-swap unloads the chat model; null keeps it resident\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chat\.ubatch



Logical and physical batch size (` -b `/` -ub `); null keeps
llama-server’s defaults\. Larger ubatches let prompt processing run
CPU-resident experts on the GPU, at more compute-buffer VRAM\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.chatURL



OpenAI API base of every role (chat, embeddings, rerank)\.



*Type:*
string *(read only)*



*Default:*

```nix
"http://127.0.0.1:${toString port}/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.commonArgs



llama-server arguments every role gets, after ` --host ` and ` --port `\.
The default offloads every layer to the GPU, enables flash
attention and stores the KV cache as q8_0\.



*Type:*
list of string



*Default:*

```nix
[
  "-ngl 999"
  "-fa on"
  "-ctk q8_0"
  "-ctv q8_0"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.contextSize



Context (` -c `) of the embedding server\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
8192
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.dimension



Output dimension of the embedding model, for clients that need it (the OpenViking config)\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```



*Example:*

```nix
2560
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.extraArgs



Extra llama-server arguments after the generated ones\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.model



GGUF weights of the embedding model: a fetched store path or a path
outside the store\. Null leaves the role unserved\.



*Type:*
null or package or string



*Default:*

```nix
null
```



*Example:*

```nix
pkgs.fetchurl {
  url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
  hash = "sha256-...";
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.name



Model id clients send in the ` model ` field\.



*Type:*
string



*Default:*

```nix
"embedding"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.pooling



Pooling type (` --pooling `); null keeps the model’s own\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"last"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.embedding\.ubatch



Logical and physical batch size (` -b `/` -ub `)\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
1024
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.gpuAccess



Put the llama-swap unit in the ` render ` and ` video ` groups\. nixpkgs’
unit runs as a DynamicUser with PrivateDevices off but no group
beyond its own, so Vulkan and ROCm cannot open the ` root:render `
0660 nodes under /dev/dri or /dev/kfd and llama\.cpp falls back to
the CPU\. Turn it off on CPU-only hosts\.

No DeviceAllow is added: the unit has no device policy, and adding
one would close every device not listed (such as the NVIDIA nodes)\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.healthCheckTimeout



Seconds llama-swap waits for a server to come up; large weights page in slowly on a cold start\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
600
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.openviking\.enable



Whether to enable pointing the OpenViking server (services\.openviking-server) at this
stack: its ` configFile ` defaults to a generated ov\.conf whose vlm,
embedding and rerank providers are the local models, and the server
starts after llama-swap\. Needs the chat and embedding roles and
` embedding.dimension `\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.openviking\.extraSettings



Top-level ov\.conf sections merged over the generated ones\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  server = {
    with_bot = true;
  };
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.openviking\.timeout



Seconds OpenViking waits on a chat request; requests can queue behind every slot\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
1200
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.openviking\.workspace



OpenViking storage workspace written into the generated ov\.conf\.



*Type:*
string



*Default:*

```nix
"/var/lib/openviking/.openviking"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.openvikingProviders



Provider settings in the shape of the OpenViking modules’ ` vlm `,
` embedding ` and ` rerank ` options, so a per-user server
(programs\.openviking-server) can take them from the system config\.



*Type:*
attribute set of attribute set of anything *(read only)*



*Default:*
` vlm `, ` embedding ` and (when served) ` rerank ` blocks for this stack

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.port



Loopback port llama-swap listens on\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8080
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.concurrencyLimit



In-flight requests llama-swap accepts before answering 429\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
64
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.extraArgs



Extra llama-server arguments after the generated ones\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.model



GGUF weights of the reranker: a fetched store path or a path
outside the store\. Null leaves the role unserved\. The GGUF must
keep the classification head and rank pooling (a conversion made
with llama\.cpp’s convert_hf_to_gguf\.py does); others score near 0\.



*Type:*
null or package or string



*Default:*

```nix
null
```



*Example:*

```nix
pkgs.fetchurl {
  url = "https://huggingface.co/<owner>/<repo>/resolve/<commit>/<file>.gguf";
  hash = "sha256-...";
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.name



Model id clients send in the ` model ` field\.



*Type:*
string



*Default:*

```nix
"rerank"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.parallel



Concurrent request slots (` -np `); the context is ` ubatch ` per slot\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
2
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerank\.ubatch



Logical and physical batch size (` -b `/` -ub `)\. A query+document pair
longer than this is rejected, so clients must cap their input
below it\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
2048
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.rerankURL



Full rerank endpoint, for clients that POST to it directly\.



*Type:*
string *(read only)*



*Default:*

```nix
"${chatURL}/rerank"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.resourceControl\.cpuWeight



CPUWeight of llama-swap and its servers; null keeps systemd’s default\.



*Type:*
null or integer between 1 and 10000 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
20
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.resourceControl\.ioWeight



IOWeight of llama-swap and its servers; null keeps systemd’s default\.



*Type:*
null or integer between 1 and 10000 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
20
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localLlm\.resourceControl\.nice



Nice level of llama-swap and its servers; null keeps the default\.



*Type:*
null or integer between -20 and 19 (both inclusive)



*Default:*

```nix
null
```



*Example:*

```nix
5
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-llm>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-llm)



## services\.localMail\.enable



Whether to enable local mailboxes (Postfix on loopback, \<user>@\<host>\.localhost)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-mail>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-mail)



## services\.localMail\.rootAlias



User receiving root and postmaster mail; null keeps it in
/var/spool/mail/root\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"alice"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-mail>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-mail)



## services\.localWeb\.enable



Whether to enable \*\.localhost names for local web UIs\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites



Sites served as http://\<name>\.localhost and listed on http://localhost\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  llm = {
    title = "llama-swap";
    port = 8080;
    extraConfig = "redir / /ui/";
  };
}

```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.enable



Whether to serve and list this site\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.description



Line shown next to the link\.



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.extraConfig



Caddy directives before the proxy, or the whole block without a port\.



*Type:*
strings concatenated with “\\n”



*Default:*

```nix
""
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.order



Position on the index page (then by name)\.



*Type:*
signed integer



*Default:*

```nix
100
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.port



Loopback port to proxy to; null leaves the block to extraConfig\.



*Type:*
null or 16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.localWeb\.sites\.\<name>\.title



Link text on the index page\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/local-web>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/local-web)



## services\.mem0\.enable



Whether to enable the self-hosted mem0 memory server\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.package



The mem0-server package to run\.



*Type:*
package



*Default:*

```nix
pkgs.mem0-server
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.auth\.adminApiKeyFile



File holding the bootstrap admin API key (sent as ` X-API-Key `)\. Unset generates one on first start under
` /var/lib/mem0-secrets `\. The file is read as a systemd credential at run
time, so it never enters the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.auth\.jwtSecretFile



File holding the secret that signs the server’s JWT sessions\. Unset generates one on first start under
` /var/lib/mem0-secrets `\. The file is read as a systemd credential at run
time, so it never enters the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.clientUsers



Users allowed to read a client API key\. When set, a one-shot unit
creates the first (admin) account and one API key in
` /var/lib/mem0-clients/api-key `, readable by the ` mem0-clients `
group these users join\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.collection



Name of the pgvector table that holds the memories\. Its vector size is
fixed when the table is created, so a new ` embedder.dims ` needs a new
collection\.



*Type:*
string



*Default:*

```nix
"memories"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.authName



Database that holds the server’s accounts and API keys\.



*Type:*
string



*Default:*

```nix
"mem0_app"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.createLocally



Provision the databases on a local ` services.postgresql `
with the pgvector extension: create both databases and the role,
set the role’s password and enable ` vector `\. With false, the server
at ` host ` must already have both databases, owned by ` user `, with
the ` vector ` extension in ` name `\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.host



Host of the PostgreSQL server (password authentication over TCP)\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.name



Database that holds the memory vectors (pgvector)\.



*Type:*
string



*Default:*

```nix
"mem0"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.passwordFile



File holding the password of ` user `\. Required with
` createLocally = false `; unset with a local server generates one on
first start under ` /var/lib/mem0-secrets `\. The server puts it in a
connection URL, so keep it to URL-safe characters\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.port



Port of the PostgreSQL server\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
if createLocally then config.services.postgresql.settings.port else 5432
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.database\.user



PostgreSQL role the server connects as\.



*Type:*
string



*Default:*

```nix
"mem0"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.apiKeyFile



File holding the API key of the embedding provider\. Unset
sends a placeholder key, for local servers that ignore it\. The file is
read as a systemd credential, so it never enters the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.baseUrl



Base URL of an OpenAI-compatible embedding server
(` openai_base_url `)\. Only for the ` openai ` provider; null uses the
OpenAI API\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"http://127.0.0.1:8080/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.dims



Vector size of the embedding model\.



*Type:*
integer between 1 and 16000 (both inclusive)



*Example:*

```nix
1536
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.model



Embedding model name\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.provider



Embedding provider\. These are the providers the mem0 server bundles;
` openai ` also covers any OpenAI-compatible server through ` baseUrl `\.



*Type:*
one of “openai”, “gemini”



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.embedder\.settings



Extra provider config fields, merged into the embedding
` config ` of the mem0 MemoryConfig\. Not for secrets: the values are
written to the Nix store\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  max_tokens = 2000;
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.host



Address the REST server binds to\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.llm\.apiKeyFile



File holding the API key of the llm provider\. Unset
sends a placeholder key, for local servers that ignore it\. The file is
read as a systemd credential, so it never enters the Nix store\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.llm\.baseUrl



Base URL of an OpenAI-compatible llm server
(` openai_base_url `)\. Only for the ` openai ` provider; null uses the
OpenAI API\.



*Type:*
null or string



*Default:*

```nix
null
```



*Example:*

```nix
"http://127.0.0.1:8080/v1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.llm\.model



LLM model name\.



*Type:*
string

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.llm\.provider



LLM provider\. These are the providers the mem0 server bundles;
` openai ` also covers any OpenAI-compatible server through ` baseUrl `\.



*Type:*
one of “openai”, “anthropic”, “gemini”



*Default:*

```nix
"openai"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.llm\.settings



Extra provider config fields, merged into the llm
` config ` of the mem0 MemoryConfig\. Not for secrets: the values are
written to the Nix store\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```



*Example:*

```nix
{
  max_tokens = 2000;
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.openFirewall



Open ` port ` in the host firewall\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.port



Port of the REST server\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
8888
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.mem0\.settings



Extra mem0 MemoryConfig fields, merged recursively over the generated
config (for example ` custom_fact_extraction_prompt `)\. Not for
secrets: the values are written to the Nix store\.



*Type:*
attribute set of anything



*Default:*

```nix
{ }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/mem0>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/mem0)



## services\.nixbuild\.enable



Whether to enable nixbuild\.net remote builder\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nixbuild>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nixbuild)



## services\.nixbuild\.maxJobs



Maximum number of concurrent build jobs



*Type:*
signed integer



*Default:*

```nix
100
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nixbuild>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nixbuild)



## services\.nixbuild\.privateKeyFile



Path to the SSH private key for nixbuild\.net authentication



*Type:*
absolute path

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nixbuild>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nixbuild)



## services\.nixbuild\.systems



List of system architectures to offload builds for



*Type:*
list of string



*Default:*

```nix
[
  "x86_64-linux"
  "aarch64-linux"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/nixbuild>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/nixbuild)



## services\.opensnitchBaseline\.enable



Whether to enable baseline OpenSnitch allow rules (loopback, system services, Nix caches)\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/opensnitch-baseline>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/opensnitch-baseline)



## services\.opensnitchBaseline\.allowPrograms



Executables allowed to connect anywhere, keyed by rule name\. Use the
path the kernel runs (the unwrapped binary for wrapped programs)\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{ slack = "${pkgs.slack}/lib/slack/slack"; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/opensnitch-baseline>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/opensnitch-baseline)



## services\.openviking-server\.enable



Whether to enable the OpenViking context-filesystem server\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.package



The openviking-server package to run\.



*Type:*
package



*Default:*

```nix
pkgs.openviking-server
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.configFile



Path to an OpenViking ` ov.conf ` (JSON) describing storage, logging,
embedding and VLM providers\. Passed as ` --config `\. When set it takes
precedence over any structured config the module would build\.



*Type:*
null or absolute path



*Default:*

```nix
null
```



*Example:*

```nix
"/run/secrets/ov.conf"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.environment



Extra environment variables for the server unit\.



*Type:*
attribute set of string



*Default:*

```nix
{ }
```



*Example:*

```nix
{ OPENVIKING_PUBLIC_BASE_URL = "https://ov.example.org"; }
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.environmentFiles



EnvironmentFiles for the unit (e\.g\. a secret-manager-rendered file),
read at start without entering the store\.



*Type:*
list of absolute path



*Default:*

```nix
[ ]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.exposeViaTailscale



Publish the server as the Tailscale Service ` svc:openviking ` (TLS on
443) through the ` expose ` module of this repository, which must be
imported, with ` services.expose.tailscale.enable ` set\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.group



System group that owns secrets the server must read\. Because the
unit uses ` DynamicUser `, secrets (e\.g\. ` configFile `) can’t be owned
by a static user; instead make them group-owned by this group with
a group-readable mode (` 0440 `)\. The dynamic user is added to the
group via ` SupplementaryGroups `\.



*Type:*
string



*Default:*

```nix
"openviking"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.host



Address the server binds to (passed as ` --host `)\. Defaults to
loopback\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.openFirewall



Open ` port ` in the host firewall\. Off by default\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.openviking-server\.port



TCP port the server binds to (passed as ` --port `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
1933
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/openviking-server>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/openviking-server)



## services\.phoenix\.enable



Whether to enable self-hosted Arize Phoenix on SQLite\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.package



The Arize Phoenix package to run\.



*Type:*
package



*Default:*

```nix
pkgs.arize-phoenix
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.grpcPort



Port of the OTLP/gRPC collector\. Phoenix cannot disable it\. The packaged
server binds it to ` services.phoenix.host ` (PHOENIX_GRPC_HOST),
and while that is a loopback address the unit may use loopback traffic
only (` IPAddressDeny `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
4317
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.host



Address the web UI, REST API and OTLP/HTTP collector bind to\.



*Type:*
string



*Default:*

```nix
"127.0.0.1"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.ingestEnvFile



Root-only ` PHOENIX_API_KEY `/` PHOENIX_COLLECTOR_ENDPOINT `/` PHOENIX_ENDPOINT ` for a
systemd ` EnvironmentFile= ` of a service that sends to Phoenix\.



*Type:*
absolute path *(read only)*



*Default:*

```nix
"/var/lib/phoenix-secrets/ingest.env"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.ingestHeadersFile



OTLP ingest headers (` {"Authorization": "Bearer ..."} `), readable by
` services.phoenix.ingestUsers `\.



*Type:*
absolute path *(read only)*



*Default:*

```nix
"/var/lib/phoenix-ingest/otlp-headers.json"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.ingestKeyFile



System API key file, readable by ` services.phoenix.ingestUsers `\.



*Type:*
absolute path *(read only)*



*Default:*

```nix
"/var/lib/phoenix-ingest/api-key"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.ingestUsers



Users allowed to read the system API key in ` services.phoenix.ingestKeyFile `
and the OTLP header file ` services.phoenix.ingestHeadersFile `\.
They become members of the ` phoenix-ingest ` group\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "alice"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.port



Port of the web UI, REST API and OTLP/HTTP collector (` /v1/traces `)\.



*Type:*
16 bit unsigned integer; between 0 and 65535 (both inclusive)



*Default:*

```nix
6006
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.retentionDays



Retention in days of the default trace retention policy, the one every
project without its own policy uses\. Phoenix applies it weekly\.
The value seeds a new database (PHOENIX_DEFAULT_RETENTION_POLICY_DAYS), and
` phoenix-ingest.service ` patches the policy of an existing database
on each start\. Null leaves the policy alone, which keeps everything
on a new database\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```



*Example:*

```nix
90
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.phoenix\.url



URL the browser reaches the web UI at (PHOENIX_ROOT_URL)\.



*Type:*
string



*Default:*

```nix
"http://localhost:${toString config.services.phoenix.port}"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/phoenix>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/phoenix)



## services\.powerPolicy\.enable



Whether to enable the full/weak/battery power-source policy\.



*Type:*
boolean



*Default:*

```nix
false
```



*Example:*

```nix
true
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.batteryDebounceSec



AC must read offline this long before the state becomes battery, so dock flaps do not count\.



*Type:*
unsigned integer, meaning >=0



*Default:*

```nix
90
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.batteryStopUnits



Service units stopped on entering battery and started again when AC
returns\. Each also gets an ExecCondition so it never starts on battery\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "inference-server.service"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.chainUnits



Units started after every successful policy run (` OnSuccess= `), so
they read a freshly written state file\. Order them ` after `
power-policy\.service too, so a boot-time start waits for the state\.



*Type:*
list of string



*Default:*

```nix
[ ]
```



*Example:*

```nix
[
  "cpu-power-limit.service"
]
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.drainThresholdWh



Drop from the window’s peak energy that marks the charger as weak\. The
default over 300 s is a sustained deficit of about 12 W\.



*Type:*
positive integer or floating point number, meaning >0



*Default:*

```nix
1.0
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.drainWindowSec



Window over which battery drain is measured while on AC\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
300
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.gpu\.maxClockMhz



Upper GPU clock lock (` nvidia-smi -lgc `) while weak; null leaves clocks alone\.



*Type:*
null or (positive integer, meaning >0)



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.gpu\.nvidiaSmi



nvidia-smi binary used for the clock lock\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.intervalSec



Seconds between timer-driven runs; Mains udev events and resume trigger extra runs\.



*Type:*
positive integer, meaning >0



*Default:*

```nix
60
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.profiles



power-profiles-daemon profile per state, set on every transition and
whenever the daemon starts\. A manual change sticks until the next
transition\. null leaves the profile alone\.



*Type:*
null or (submodule)



*Default:*

```nix
null
```



*Example:*

```nix
{
  battery = "balanced";
  full = "performance";
  weak = "balanced";
}
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.profiles\.battery



power-profiles-daemon profile while the state is battery\.



*Type:*
one of “performance”, “balanced”, “power-saver”

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.profiles\.full



power-profiles-daemon profile while the state is full\.



*Type:*
one of “performance”, “balanced”, “power-saver”

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.profiles\.weak



power-profiles-daemon profile while the state is weak\.



*Type:*
one of “performance”, “balanced”, “power-saver”

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)



## services\.powerPolicy\.stateDir



Directory holding the ` state ` file (full, weak or battery) other units read\.



*Type:*
string *(read only)*



*Default:*

```nix
"/run/power-policy"
```

*Declared by:*
 - [\<nixpkgs-extra/modules/nixos/power-policy>](https://github.com/Jylhis/nixpkgs-extra/blob/main/modules/nixos/power-policy)


