# GhidraMCP: Ghidra plugin plus a Python MCP bridge to its HTTP server.
#
# `passthru.extension` is the Java plugin, compiled with javac against this
# package set's ghidra jars instead of upstream's Maven build, and shaped like
# `ghidra.buildGhidraExtension` output for `pkgs.ghidra.withExtensions`.
# Upstream 1.4 targets Ghidra 11.3.2; the plugin only uses stable core APIs.
{
  lib,
  stdenv,
  fetchFromGitHub,
  jdk21,
  makeWrapper,
  python3,
  ghidra,
  nix-update-script,
}:
let
  version = "2.0";

  src = fetchFromGitHub {
    owner = "LaurieWired";
    repo = "GhidraMCP";
    tag = version;
    hash = "sha256-kd7ITLhjT6KJL/sWUX8ySskhZh6nCzDG6AILgtJqJPM=";
  };

  ghidraVersion = lib.getVersion ghidra;

  metaCommon = {
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    homepage = "https://github.com/LaurieWired/GhidraMCP";
    downloadPage = "https://github.com/LaurieWired/GhidraMCP/releases/tag/${version}";
    changelog = "https://github.com/LaurieWired/GhidraMCP/releases/tag/${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ jylhis ];
  };

  extension = stdenv.mkDerivation {
    pname = "ghidra-mcp-extension";
    inherit version src;

    nativeBuildInputs = [ jdk21 ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild

      ghidraLib=${ghidra}/lib/ghidra/Ghidra
      classpath=$ghidraLib/Features/Base/lib/Base.jar:$ghidraLib/Features/Decompiler/lib/Decompiler.jar
      classpath+=:$ghidraLib/Framework/Docking/lib/Docking.jar:$ghidraLib/Framework/Generic/lib/Generic.jar
      classpath+=:$ghidraLib/Framework/Project/lib/Project.jar:$ghidraLib/Framework/SoftwareModeling/lib/SoftwareModeling.jar
      classpath+=:$ghidraLib/Framework/Utility/lib/Utility.jar:$ghidraLib/Framework/Gui/lib/Gui.jar

      mkdir -p build/classes
      javac -encoding UTF-8 -d build/classes -cp "$classpath" \
        src/main/java/com/lauriewired/GhidraMCPPlugin.java
      jar cfm build/GhidraMCP.jar src/main/resources/META-INF/MANIFEST.MF -C build/classes .

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      ext=$out/lib/ghidra/Ghidra/Extensions/GhidraMCP
      install -Dm444 build/GhidraMCP.jar "$ext/lib/GhidraMCP.jar"
      install -Dm444 src/main/resources/Module.manifest "$ext/Module.manifest"

      # Ghidra refuses to load a plugin whose ghidraVersion differs from its own.
      cat > "$ext/extension.properties" <<EOF
      name=GhidraMCP
      description=A plugin that runs an embedded HTTP server to expose program data.
      author=LaurieWired
      createdOn=2025-03-22
      version=${ghidraVersion}
      ghidraVersion=${ghidraVersion}
      EOF

      # Prevent attempted creation of plugin lock files in the Nix store.
      touch "$ext/.dbDirLock"

      runHook postInstall
    '';

    meta = metaCommon // {
      description = "Ghidra plugin: embedded HTTP server for the GhidraMCP bridge";
      platforms = ghidra.meta.platforms;
    };
  };
  pythonEnv = python3.withPackages (ps: [
    ps.mcp
    ps.requests
  ]);
in
stdenv.mkDerivation {
  pname = "ghidra-mcp-bridge";
  inherit version src;

  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm444 bridge_mcp_ghidra.py $out/share/ghidra-mcp/bridge_mcp_ghidra.py
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/ghidra-mcp-bridge \
      --add-flags $out/share/ghidra-mcp/bridge_mcp_ghidra.py

    runHook postInstall
  '';

  passthru = {
    category = "Reverse engineering";
    # The Ghidra plugin; drops into `pkgs.ghidra.withExtensions`.
    inherit extension;
    updateScript = nix-update-script { };
  };

  meta = metaCommon // {
    description = "MCP bridge connecting MCP clients to a running GhidraMCP plugin";
    mainProgram = "ghidra-mcp-bridge";
    platforms = lib.platforms.unix;
  };
}
