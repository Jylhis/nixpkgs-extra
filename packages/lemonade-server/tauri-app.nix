# Adapted from noamsto/nix-amd-ai (MIT), rev 4536648, pkgs/lemonade/tauri-app.nix.
{
  lib,
  rustPlatform,
  pkg-config,
  wrapGAppsHook3,
  webkitgtk_4_1,
  openssl,
  libayatana-appindicator,
  glib,
  gtk3,
  librsvg,
  gst_all_1,
  pipewire,
  version,
  src,
  tauri-frontend,
}:
rustPlatform.buildRustPackage {
  pname = "lemonade-app";
  inherit version src;

  sourceRoot = "${src.name}/src/app/src-tauri";

  cargoHash = "sha256-xX2Wkk0QqCQ//YoxeQBLTWfGEfyIR8JJKArYLzaAc0g=";

  # generate_context!() embeds frontendDist (../dist/renderer relative to
  # src-tauri/) at compile time, so the bundle must land there before cargo
  # runs. The source is read-only, hence `chmod u+w ..`.
  preBuild = ''
    chmod u+w ..
    mkdir ../dist
    cp -r ${tauri-frontend} ../dist/renderer
  '';

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
  ];

  buildInputs = [
    webkitgtk_4_1
    openssl
    libayatana-appindicator
    glib
    gtk3
    librsvg
    # WebKit getUserMedia needs webrtcdsp (gst-plugins-bad) and pipewiresrc
    # (pipewire) for mic capture; wrapGAppsHook3 adds them to the plugin path.
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-libav
    pipewire
  ];

  # `tauri/custom-protocol` switches tauri-codegen from dev mode (devUrl
  # :9123) to embedded assets. `cargo tauri build` sets it; buildRustPackage
  # does not, and without it the window opens blank.
  buildFeatures = [ "tauri/custom-protocol" ];

  doCheck = false;

  # Mirror the CMake install rules for BUILD_TAURI_APP=ON so `from-source.nix`
  # can symlink $out/{bin,share}/...
  postInstall = ''
    install -Dm644 $src/data/lemonade-app.desktop $out/share/applications/lemonade-app.desktop
    install -Dm644 $src/src/app/assets/logo.svg $out/share/pixmaps/lemonade-app.svg
  '';

  meta = {
    description = "Lemonade desktop app (Tauri shell around the React UI)";
    homepage = "https://github.com/lemonade-sdk/lemonade";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "lemonade-app";
  };
}
