# Lemonade Server: OpenAI-compatible local AI server (lemond + CLI + web UI +
# optional Tauri desktop app), built from source with NixOS patches. Needs
# libwebsockets 4.5.8 (see ../libwebsockets_4_5).
# Adapted from noamsto/nix-amd-ai (MIT), rev 4536648, pkgs/lemonade.
{
  lib,
  stdenv,
  callPackage,
  nix-update-script,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  python3,
  jq,
  nlohmann_json,
  cli11,
  curl,
  zstd,
  brotli,
  httplib,
  libwebsockets_4_5,
  mbedtls,
  openssl,
  systemd,
  libcap,
  libdrm,
  fastflowlm,
  llama-cpp-rocm,
  llama-cpp-vulkan,
  whisper-cpp,
  whisper-cpp-vulkan,
  stable-diffusion-cpp,
  stable-diffusion-cpp-rocm,
  stable-diffusion-cpp-vulkan,
  # Default-on; flip off via .override to skip the npm/Rust builds.
  withWebApp ? true,
  withDesktopApp ? true,
}:
let
  version = "11.5.2";

  src = fetchFromGitHub {
    owner = "lemonade-sdk";
    repo = "lemonade";
    tag = "v${version}";
    hash = "sha256-vt1BFdNKpM6OM15jatxJbBduClibKdbcON9AGcZ0Rtc=";
  };

  web-app = callPackage ./web-app.nix { inherit src version; };
  tauri-frontend = callPackage ./tauri-frontend.nix { inherit src version; };
  tauri-app = callPackage ./tauri-app.nix { inherit src version tauri-frontend; };
in
stdenv.mkDerivation {
  pname = "lemonade";
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    python3
    jq
  ];

  buildInputs = [
    nlohmann_json
    cli11
    curl
    zstd
    brotli
    httplib
    libwebsockets_4_5
    mbedtls
    openssl
    systemd
    libcap
    libdrm
  ];

  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    # Web app and Tauri are separate derivations merged in postInstall.
    (lib.cmakeBool "BUILD_WEB_APP" false)
    (lib.cmakeBool "BUILD_TAURI_APP" false)
    (lib.cmakeBool "REQUIRE_LINUX_TRAY" false)
  ];

  postPatch = ''
        # Two install(CODE ...) blocks symlink into /usr/bin and
        # /usr/lib/systemd/system via $ENV{DESTDIR} (Debian staging). DESTDIR is
        # unset here, so they resolve to /usr and the sandbox refuses; drop them.
        sed -i '/Create symlink in standard bin path only if not installing to/,/^endif()$/d' \
          src/cpp/cli/CMakeLists.txt
        # singular/plural tolerant: v10.8.1 pluralized the comment ("symlinks ... search paths").
        sed -i '/Create symlinks\? in standard systemd search paths\? only if not installing to/,/^    endif()$/d' CMakeLists.txt

        # The secrets.conf install rule writes to /etc/lemonade/conf.d, which
        # the NixOS module owns; relocate the template under $out.
        substituteInPlace CMakeLists.txt \
          --replace-fail \
            'DESTINATION /etc/lemonade/conf.d' \
            'DESTINATION share/lemonade/conf.d.example'

        # Honor LEMONADE_DEFAULTS_PATH: v10.7.0 dropped the LEMONADE_*_BIN env
        # migration, and get_defaults() only reads /usr/share/lemonade, which
        # NixOS doesn't populate. Mirrors LEMONADE_GGML_HIP_PATH (#2044).
        # Drop once the upstream proposal lands.
        substituteInPlace src/cpp/server/config_file.cpp \
          --replace-fail \
            '    return defaults;
    }' \
            '    if (const char* env = std::getenv("LEMONADE_DEFAULTS_PATH"); env && *env && fs::exists(env)) {
            defaults = utils::JsonUtils::merge(defaults, load_json_file(env));
        }

        return defaults;
    }'

        # Don't abort downloads when the SSE progress socket goes away:
        # WebKitGTK suspends backgrounded windows after ~60-90s, losing GBs of
        # partial download. See noamsto/nix-amd-ai#5.
        substituteInPlace src/cpp/server/server.cpp \
          --replace-fail \
            'if (!sink.write(event.c_str(), event.size())) {
                            LOG(INFO, "Server") << "Client disconnected, cancelling download" << std::endl;
                            return false;
                        }
                        return true;' \
            'if (!sink.write(event.c_str(), event.size())) {
                            LOG(INFO, "Server") << "Client disconnected; download continues in background" << std::endl;
                        }
                        return true;'

        # Never fetch the downloaded "TheRock" ROCm runtime: its lib/ shadows
        # our ROCm libs and needs libatomic.so.1, absent on NixOS (loader exits
        # 127, #57). Keep the therock key so get_therock_version() lookups
        # don't throw.
        substituteInPlace src/cpp/server/backend_manager.cpp \
          --replace-fail \
            'bool will_install_therock(const std::string& os, const json& backend_versions) {' \
            'bool will_install_therock(const std::string& os, const json& backend_versions) {
        return false;  // nix-amd-ai#57: ship self-contained ROCm binaries, never fetch TheRock'

        # Pin backend_versions.json to the backends we ship so the "needs
        # update" check passes and nothing is downloaded at runtime. One sd-cpp
        # version covers all three keys (same upstream commit).
        if [ -f src/cpp/resources/backend_versions.json ]; then
          jq '.flm.npu = "v${fastflowlm.version}"
              | .llamacpp."rocm-stable" = "b${llama-cpp-rocm.version}"
              | .llamacpp.vulkan = "b${llama-cpp-vulkan.version}"
              | .whispercpp.cpu = "v${whisper-cpp.version}"
              | .whispercpp.vulkan = "v${whisper-cpp-vulkan.version}"
              | ."sd-cpp".cpu = "${stable-diffusion-cpp.version}"
              | ."sd-cpp"."rocm-stable" = "${stable-diffusion-cpp-rocm.version}"
              | ."sd-cpp".vulkan = "${stable-diffusion-cpp-vulkan.version}"' \
            src/cpp/resources/backend_versions.json > src/cpp/resources/backend_versions.json.tmp
          mv src/cpp/resources/backend_versions.json.tmp src/cpp/resources/backend_versions.json
        fi
  '';

  # lemond looks for resources/ next to its binary; the bin/resources symlink
  # satisfies that. The web UI is a symlink to the buildNpmPackage output.
  postInstall = ''
    ln -s ../share/lemonade-server/resources $out/bin/resources
  ''
  + lib.optionalString withWebApp ''
    ln -s ${web-app} $out/share/lemonade-server/resources/web-app
  ''
  + lib.optionalString withDesktopApp ''
    ln -s ${tauri-app}/bin/lemonade-app $out/bin/lemonade-app
    install -d $out/share/applications $out/share/pixmaps
    ln -s ${tauri-app}/share/applications/lemonade-app.desktop $out/share/applications/lemonade-app.desktop
    ln -s ${tauri-app}/share/pixmaps/lemonade-app.svg $out/share/pixmaps/lemonade-app.svg
  '';

  # Inner staging derivations, buildable on their own for hash refresh:
  #   nix build .#lemonade-server.web-app
  #   nix build .#lemonade-server.tauri-frontend
  #   nix build .#lemonade-server.tauri-app
  passthru = {
    inherit web-app tauri-frontend tauri-app;
    category = "AMD NPU";
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Local AI server with OpenAI-compatible API for NPU/GPU inference";
    homepage = "https://github.com/lemonade-sdk/lemonade";
    changelog = "https://github.com/lemonade-sdk/lemonade/releases/tag/v${version}";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "lemond";
  };
}
