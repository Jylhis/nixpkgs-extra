# nixpkgs-extra

Nix packages and NixOS / Home Manager modules that are not in nixpkgs.
x86_64-linux and aarch64-linux.

## Use

With flakes:

```nix
{
  inputs.nixpkgs-extra.url = "github:Jylhis/nixpkgs-extra";

  outputs = { nixpkgs, nixpkgs-extra, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        # every package at the top level of pkgs
        { nixpkgs.overlays = [ nixpkgs-extra.overlays.default ]; }
        nixpkgs-extra.nixosModules.opensnitch-baseline
        { services.opensnitchBaseline.enable = true; }
      ];
    };
  };
}
```

Run a package directly: `nix run github:Jylhis/nixpkgs-extra#<name>`.

Without flakes, `default.nix` takes your nixpkgs:

```nix
let
  extra = import (fetchTarball "https://github.com/Jylhis/nixpkgs-extra/archive/main.tar.gz") {
    inherit pkgs;
  };
in
extra.packages.<name> # also extra.overlays.default, extra.nixosModules, extra.homeModules
```

Modules don't need the overlay: their `package` options default to this
repo's builds. The overlay only adds the packages to `pkgs`.

Option references: [NixOS modules](docs/nixos-options.md),
[Home Manager modules](docs/home-options.md).

## Packages

<!-- BEGIN PACKAGES -->
### AI tools

- [`bifrost`](packages/bifrost/package.nix): Go LLM gateway with a web UI, governance and observability plugins ([homepage](https://github.com/maximhq/bifrost))
- [`ds4`](packages/ds4/package.nix): Native DeepSeek V4 inference engine with a Strix Halo ROCm backend ([homepage](https://github.com/antirez/ds4))
- [`mem0-server`](packages/mem0-server/package.nix): Self-hosted mem0 REST API server ([homepage](https://github.com/mem0ai/mem0/tree/main/server))
- [`mem0ai`](packages/mem0ai/package.nix): Long-term memory layer for AI agents ([homepage](https://github.com/mem0ai/mem0))
- [`openhands`](packages/openhands/package.nix): AI software engineering agent with the Agent Canvas web interface ([homepage](https://github.com/OpenHands/OpenHands))
- [`openviking-server`](packages/openviking-server/package.nix): Server for OpenViking, a context filesystem for AI agents ([homepage](https://openviking.ai))

### AMD NPU

- [`dynamic-dispatch`](packages/dynamic-dispatch/package.nix): Dynamic operator dispatch for AMD Ryzen AI ([homepage](https://github.com/amd/DynamicDispatch))
- [`fastflowlm`](packages/fastflowlm/package.nix): NPU-optimized LLM runtime for AMD Ryzen AI ([homepage](https://github.com/FastFlowLM/FastFlowLM))
- [`graph-engine`](packages/graph-engine/package.nix): Graph execution engine for AMD Vitis AI ([homepage](https://github.com/amd/graph_engine))
- [`lemonade-server`](packages/lemonade-server/package.nix): Local AI server with OpenAI-compatible API for NPU/GPU inference ([homepage](https://github.com/lemonade-sdk/lemonade))
- [`mlir-aie`](packages/mlir-aie/package.nix): MLIR-based toolchain for the AMD AI Engine ([homepage](https://github.com/Xilinx/mlir-aie))
- [`onnxruntime-vitisai`](packages/onnxruntime-vitisai/package.nix): ONNX Runtime with the VitisAI execution provider for the AMD Ryzen AI NPU ([homepage](https://github.com/microsoft/onnxruntime))
- [`python-onnxruntime-vitisai`](packages/python-onnxruntime-vitisai/package.nix): ONNX Runtime Python bindings with the VitisAI execution provider ([homepage](https://github.com/microsoft/onnxruntime))
- [`target-factory`](packages/target-factory/package.nix): Factory to generate DPU target descriptions for AMD Vitis AI ([homepage](https://github.com/amd/target_factory))
- [`trace-logging`](packages/trace-logging/package.nix): Trace logging library for AMD Vitis AI ([homepage](https://github.com/amd/trace_logging))
- [`unilog`](packages/unilog/package.nix): Unified logging library for AMD Vitis AI ([homepage](https://github.com/amd/unilog))
- [`vart`](packages/vart/package.nix): Vitis AI Runtime for AMD accelerators ([homepage](https://github.com/amd/vart))
- [`vllm-rocm`](packages/vllm-rocm/package.nix): Prebuilt vLLM with the TheRock ROCm backend for AMD Strix APUs ([homepage](https://github.com/lemonade-sdk/vllm-rocm))
- [`xaiengine`](packages/xaiengine/package.nix): AMD AI Engine runtime driver library ([homepage](https://github.com/Xilinx/aie-rt))
- [`xir`](packages/xir/package.nix): Xilinx Intermediate Representation for deep learning algorithms ([homepage](https://github.com/amd/xir))
- [`xrt`](packages/xrt/package.nix): Xilinx Runtime (XRT) for AMD Ryzen AI NPU ([homepage](https://github.com/Xilinx/XRT))
- [`xrt-plugin-amdxdna`](packages/xrt-plugin-amdxdna/package.nix): AMD XDNA driver plugin for XRT, adding Ryzen AI NPU support ([homepage](https://github.com/amd/xdna-driver))

### Desktop applications

- [`mermaid-live-editor`](packages/mermaid-live-editor/package.nix): Live editor for Mermaid diagrams ([homepage](https://github.com/mermaid-js/mermaid-live-editor))

### Developer tools

- [`ccache-storage-http-cpp`](packages/ccache-storage-http-cpp/package.nix): Remote storage helper for ccache using HTTP/HTTPS servers ([homepage](https://github.com/ccache/ccache-storage-http-cpp))
- [`create-cloudflare`](packages/create-cloudflare/package.nix): CLI for scaffolding Cloudflare Workers projects, also known as C3 ([homepage](https://github.com/cloudflare/workers-sdk/tree/main/packages/create-cloudflare))
- [`ellsp`](packages/ellsp/package.nix): Language Server Protocol server for Emacs Lisp ([homepage](https://github.com/elisp-lsp/Ellsp))
- [`haxe-lime`](packages/haxe-lime/package.nix): Foundational Haxe framework for cross-platform native and web development ([homepage](https://lime.openfl.org/))
- [`hxp`](packages/hxp/package.nix): Cross-platform build tools for desktop, mobile, web and consoles ([homepage](https://github.com/openfl/hxp))
- [`nix-ccache`](packages/nix-ccache/package.nix): Wrapper around ccache with a fixed cache directory for sandboxed Nix builds ([homepage](https://github.com/Jylhis/nixpkgs-extra/tree/main/packages/nix-ccache))
- [`nvidia-cli`](packages/nvidia-cli/package.nix): NVIDIA NGC command-line interface ([homepage](https://org.ngc.nvidia.com/setup/installers/cli))
- [`robotcode`](packages/robotcode/package.nix): Language server, debugger and CLI for Robot Framework ([homepage](https://robotcode.io))
- [`robotframework-robocop`](packages/robotframework-robocop/package.nix): Linter and formatter for Robot Framework ([homepage](https://github.com/MarketSquare/robotframework-robocop))
- [`workerd`](packages/workerd/package.nix): Cloudflare Workers JavaScript/Wasm runtime ([homepage](https://github.com/cloudflare/workerd))

### Media

- [`lazylibrarian`](packages/lazylibrarian/package.nix): Follows authors and downloads their ebooks, audiobooks and magazines ([homepage](https://lazylibrarian.gitlab.io/))

### Memory & Code Intelligence

- [`openviking`](packages/openviking/package.nix): Command-line client for OpenViking, a context filesystem for AI agents ([homepage](https://openviking.ai))

### Networking

- [`oryx`](packages/oryx/package.nix): TUI for sniffing network traffic using eBPF ([homepage](https://github.com/pythops/oryx))

### Observability

- [`arize-phoenix`](packages/arize-phoenix/package.nix): Self-hosted LLM tracing, evaluation and prompt management from Arize ([homepage](https://github.com/Arize-ai/phoenix))
- [`arize-phoenix-client`](packages/arize-phoenix-client/package.nix): Client for the Arize Phoenix LLM observability API ([homepage](https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-client))
- [`arize-phoenix-evals`](packages/arize-phoenix-evals/package.nix): LLM evaluation tools from Arize Phoenix ([homepage](https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-evals))
- [`arize-phoenix-otel`](packages/arize-phoenix-otel/package.nix): OpenTelemetry wrappers for sending traces to Arize Phoenix ([homepage](https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-otel))
- [`langfuse`](packages/langfuse/package.nix): Open source LLM engineering platform: observability, evals, prompt management ([homepage](https://langfuse.com))
- [`phoenix-mcp`](packages/phoenix-mcp/package.nix): Model Context Protocol server for Arize Phoenix ([homepage](https://github.com/Arize-ai/phoenix/tree/main/js/packages/phoenix-mcp))

### Reverse engineering

- [`ghidra-mcp`](packages/ghidra-mcp/package.nix): MCP bridge connecting MCP clients to a running GhidraMCP plugin ([homepage](https://github.com/LaurieWired/GhidraMCP))

### Robotics

- [`gz-common`](packages/gz-common/package.nix): Common libraries for Gazebo robot simulation ([homepage](https://github.com/gazebosim/gz-common))
- [`gz-fuel-tools`](packages/gz-fuel-tools/package.nix): Client library and command-line tools for Gazebo Fuel servers ([homepage](https://github.com/gazebosim/gz-fuel-tools))
- [`gz-msgs`](packages/gz-msgs/package.nix): Protobuf messages for Gazebo robot simulation ([homepage](https://github.com/gazebosim/gz-msgs))
- [`gz-plugin`](packages/gz-plugin/package.nix): Cross-platform C++ library for dynamically loading Gazebo plugins ([homepage](https://github.com/gazebosim/gz-plugin))
- [`gz-tools`](packages/gz-tools/package.nix): Command-line front end for Gazebo libraries ([homepage](https://github.com/gazebosim/gz-tools))
- [`gz-transport`](packages/gz-transport/package.nix): Transport library for Gazebo component communication ([homepage](https://github.com/gazebosim/gz-transport))
- [`sdformat`](packages/sdformat/package.nix): Simulation Description Format (SDFormat) parser and description files ([homepage](https://github.com/gazebosim/sdformat))
<!-- END PACKAGES -->

## Overrides

`overlays.overrides` replaces these nixpkgs attributes in place. It is
separate from `overlays.default` and opt-in: everything in your system that
depends on an overridden attribute rebuilds (libsolv and librepo feed dnf5,
micromamba and others), and the binary cache no longer covers it.

```nix
{ nixpkgs.overlays = [ nixpkgs-extra.overlays.overrides ]; }
```

The `llm-agents.*` entries replace packages of
[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) inside
`pkgs.llm-agents`. Apply `overlays.llm-agents` after llm-agents'
`overlays.shared-nixpkgs`; without that set it does nothing.

```nix
{
  nixpkgs.overlays = [
    llm-agents.overlays.shared-nixpkgs
    nixpkgs-extra.overlays.llm-agents
  ];
}
```

<!-- BEGIN OVERRIDES -->
- [`aider-chat`](overrides/aider-chat.nix): aider-chat with bash and zsh completions, generated by `aider --shell-completions`.
- [`cf-vault`](overrides/cf-vault.nix): cf-vault 0.0.22 (nixpkgs has 0.0.18); later tags need Go 1.27.
- [`grafanaPlugins`](overrides/grafanaPlugins.nix): grafanaPlugins with marcusolsson-treemap-panel, missing next to its marcusolsson siblings.
- [`haxePackages`](overrides/haxePackages.nix): haxePackages with hxcpp 4.3.171 (nixpkgs has 4.1.15, too old for lime 8.x).
- [`librepo`](overrides/librepo.nix): librepo with HTML API docs (doc output), separate debug info and FindLibrepo.cmake.
- [`libsolv`](overrides/libsolv.nix): libsolv with Debian repository support (deb2solv, testcase Debian solving).
- [`llm-agents.agentsview`](llm-agents-overrides/agentsview.nix): agentsview with its `cmd/agentsview` Go tests run at build time (llm-agents skips them).
- [`llm-agents.open-code-review`](llm-agents-overrides/open-code-review.nix): open-code-review with git on the `ocr` wrapper's PATH and its Claude Code plugin (`passthru.claudeCodePlugin`).
<!-- END OVERRIDES -->

## Contributing

[AGENTS.md](AGENTS.md) covers layout and conventions. Run `nix fmt`,
`nix run .#update-docs` and `nix flake check` before opening a pull request.

## License

MIT, see [LICENSE](LICENSE). Packaged software keeps its own license, listed
in each package's `meta.license`. Files adapted from other projects are
listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
