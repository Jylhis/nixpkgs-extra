# oryx: eBPF network-traffic sniffer TUI (https://github.com/pythops/oryx)
#
# Two stages: the `oryx-ebpf` crate is cross-compiled to `bpfel-unknown-none`
# with bpf-linker, then the object is placed where `oryx-tui`'s
# include_bytes_aligned! expects it before the userspace binary is built.
{
  lib,
  stdenv,
  writeText,
  fetchFromGitHub,
  rustPlatform,
  rustc,
  cargo,
  bpf-linker,
}:
let
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "pythops";
    repo = "oryx";
    tag = "v${version}";
    hash = "sha256-nPYfLLkWL0N8SjNMHTCXPhmG2kwuHKAdvDYIOoWYfc4=";
  };

  networkTypesHash = "sha256-jcVx0t7nP6sJ2wNq4395UzOsbd4soVOy/jkL4GezfRo=";

  ebpfVendor = rustPlatform.importCargoLock {
    lockFile = ./oryx-ebpf-Cargo.lock;
    outputHashes."network-types-0.1.0" = networkTypesHash;
  };

  # Vendor config mapping crates-io and network-types to the vendor directory.
  ebpfCargoConfig = writeText "config.toml" ''
    [source.crates-io]
    replace-with = "vendored-sources"

    [source."git+https://github.com/vadorovsky/network-types?rev=c6f9c28"]
    git = "https://github.com/vadorovsky/network-types"
    rev = "c6f9c28"
    replace-with = "vendored-sources"

    [source.vendored-sources]
    directory = "${ebpfVendor}"
  '';

  # Stage 1: the eBPF object. oryx-ebpf is its own crate and its
  # .cargo/config.toml pins the target; cargoSetupHook's vendor wiring does
  # not survive cross-compiling a workspace subdir, so vendor sources are
  # configured explicitly.
  oryx-ebpf = stdenv.mkDerivation {
    pname = "oryx-ebpf";
    inherit version src;

    nativeBuildInputs = [
      rustc
      cargo
      bpf-linker
    ];

    # nixpkgs' rustc ships core for bpfel-unknown-none, so upstream's
    # `-Z build-std=core` (and the nightly toolchain it needs) can go.
    postPatch = ''
      substituteInPlace oryx-ebpf/.cargo/config.toml \
        --replace-fail 'build-std = ["core"]' ""
    '';

    # oryx-common enables trivial_bounds; aya-ebpf asm_experimental_arch.
    env.RUSTC_BOOTSTRAP = 1;

    buildPhase = ''
      runHook preBuild
      export CARGO_HOME="$TMPDIR/cargo-home"
      mkdir -p "$CARGO_HOME"
      cp ${ebpfCargoConfig} "$CARGO_HOME/config.toml"
      ( cd oryx-ebpf && cargo build --release --offline --frozen )
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm0644 target/bpfel-unknown-none/release/oryx "$out"
      runHook postInstall
    '';
  };
in
rustPlatform.buildRustPackage {
  pname = "oryx";
  inherit version src;

  cargoLock = {
    lockFile = ./Cargo.lock;
    outputHashes."network-types-0.1.0" = networkTypesHash;
  };

  # oryx-common, shared with the eBPF crate, enables trivial_bounds.
  env.RUSTC_BOOTSTRAP = 1;

  # Use the vendored lockfile (bumped past upstream's for rand/time advisories).
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  # Where oryx-tui's include_bytes resolves the eBPF object.
  preBuild = ''
    mkdir -p target/bpfel-unknown-none/release
    cp ${oryx-ebpf} target/bpfel-unknown-none/release/oryx
  '';

  # Only the userspace TUI binary; xtask is a build helper.
  cargoBuildFlags = [
    "-p"
    "oryx-tui"
  ];
  doCheck = false;

  # No updateScript: Cargo.lock and oryx-ebpf-Cargo.lock are vendored and
  # refreshed by hand.
  passthru.category = "Networking";

  meta = {
    description = "TUI for sniffing network traffic using eBPF";
    homepage = "https://github.com/pythops/oryx";
    changelog = "https://github.com/pythops/oryx/releases/tag/v${version}";
    license = lib.licenses.gpl3Only;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    mainProgram = "oryx";
    platforms = lib.platforms.linux;
  };
}
