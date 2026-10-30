# oryx: eBPF network-traffic sniffer TUI (https://github.com/pythops/oryx)
#
# Two stages: the `oryx-ebpf` crate is cross-compiled to `bpfel-unknown-none`
# with a fenix nightly (bpf-linker, `-Z build-std`), then the object is placed
# where `oryx-tui`'s include_bytes_aligned! expects it before the userspace
# binary is built.
{
  lib,
  stdenv,
  runCommand,
  writeText,
  fetchFromGitHub,
  makeRustPlatform,
  fenix,
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

  # Nightly with rust-src for `-Z build-std=core` on the tier-3 bpfel target.
  # Pinned to an LLVM 21 nightly to match nixpkgs' bpf-linker; LLVM 22
  # bitcode is unreadable to bpf-linker 0.9.x. Keep rust-std-Cargo.lock in
  # sync with this date.
  #
  # Built from a vendored channel manifest because `fenix.toolchainOf` fetches
  # it at evaluation time (IFD). Refresh channel-rust-nightly.toml from
  # https://static.rust-lang.org/dist/<date>/channel-rust-nightly.toml.
  toolchain = (fenix.fromManifestFile ./channel-rust-nightly.toml).withComponents [
    "cargo"
    "rustc"
    "rust-src"
  ];
  rustPlatform = makeRustPlatform {
    cargo = toolchain;
    rustc = toolchain;
  };

  networkTypesHash = "sha256-jcVx0t7nP6sJ2wNq4395UzOsbd4soVOy/jkL4GezfRo=";

  # `-Z build-std=core` needs the std crates' dependencies vendored alongside
  # the eBPF crate's; merge both into one cargoDeps directory.
  ebpfVendor = rustPlatform.importCargoLock {
    lockFile = ./oryx-ebpf-Cargo.lock;
    outputHashes."network-types-0.1.0" = networkTypesHash;
  };
  # rust-std's Cargo.lock for the pinned nightly (2025-11-15); refresh with
  # channel-rust-nightly.toml.
  stdVendor = rustPlatform.importCargoLock {
    lockFile = ./rust-std-Cargo.lock;
  };
  ebpfCargoDeps = runCommand "oryx-ebpf-cargo-deps" { } ''
    mkdir -p "$out"
    cp -a ${ebpfVendor}/. "$out"/
    chmod -R u+w "$out"
    for d in ${stdVendor}/*/; do
      name=$(basename "$d")
      [ -e "$out/$name" ] || cp -a "$d" "$out/$name"
    done
  '';

  # Vendor config mapping crates-io and network-types to the merged directory.
  ebpfCargoConfig = writeText "config.toml" ''
    [source.crates-io]
    replace-with = "vendored-sources"

    [source."git+https://github.com/vadorovsky/network-types?rev=c6f9c28"]
    git = "https://github.com/vadorovsky/network-types"
    rev = "c6f9c28"
    replace-with = "vendored-sources"

    [source.vendored-sources]
    directory = "${ebpfCargoDeps}"
  '';

  # Stage 1: the eBPF object. oryx-ebpf is its own crate and its
  # .cargo/config.toml pins the target and build-std; cargoSetupHook's vendor
  # wiring does not survive cross-compiling a workspace subdir, so vendor
  # sources are configured explicitly.
  oryx-ebpf = stdenv.mkDerivation {
    pname = "oryx-ebpf";
    inherit version src;

    nativeBuildInputs = [
      toolchain
      bpf-linker
    ];

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

  # No updateScript: Cargo.lock and the std/eBPF lockfiles are vendored and
  # refreshed by hand with the pinned nightly.
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
