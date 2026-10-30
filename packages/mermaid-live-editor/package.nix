# Mermaid live editor, served as a static web app.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  nodejs,
  pnpm,
  fetchPnpmDeps,
  pnpmConfigHook,
  electron,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
}:

let
  pname = "mermaid-live-editor";
  version = "2.0.67";

  src = fetchFromGitHub {
    owner = "mermaid-js";
    repo = "mermaid-live-editor";
    rev = "13f90b070c9133a186d37158f6e87c92238f328c";
    hash = "sha256-ambFtlwxPwyFcQ1jcwxKzjPy/AQOweT7EwSk9ClGPaw=";
  };

  # Electron main process: serves the static web app on a local port
  # and opens it in a BrowserWindow. Using HTTP instead of file:// avoids
  # CORS and web-worker restrictions imposed by Chromium on file:// origins.
  electronMain = builtins.toFile "main.js" ''
    const { app, BrowserWindow } = require('electron');
    const path = require('path');
    const http = require('http');
    const fs = require('fs');

    const mimeTypes = {
      '.html': 'text/html',
      '.js': 'application/javascript',
      '.mjs': 'application/javascript',
      '.css': 'text/css',
      '.json': 'application/json',
      '.png': 'image/png',
      '.svg': 'image/svg+xml',
      '.ico': 'image/x-icon',
      '.wasm': 'application/wasm',
      '.txt': 'text/plain',
      '.webp': 'image/webp',
      '.woff2': 'font/woff2',
      '.woff': 'font/woff',
      '.ttf': 'font/ttf',
    };

    const webDir = path.join(__dirname, 'web');

    function startServer() {
      return new Promise((resolve) => {
        const server = http.createServer((req, res) => {
          const reqPath = decodeURIComponent(req.url.split('?')[0]);
          let filePath = path.join(webDir, reqPath);

          // Prevent path traversal
          if (!filePath.startsWith(webDir)) {
            res.writeHead(403);
            res.end('Forbidden');
            return;
          }

          // Directory -> index.html
          if (fs.existsSync(filePath) && fs.statSync(filePath).isDirectory()) {
            filePath = path.join(filePath, 'index.html');
          }

          // SPA fallback
          if (!fs.existsSync(filePath)) {
            filePath = path.join(webDir, 'index.html');
          }

          const ext = path.extname(filePath).toLowerCase();
          const contentType = mimeTypes[ext] || 'application/octet-stream';

          fs.readFile(filePath, (err, data) => {
            if (err) {
              res.writeHead(404);
              res.end('Not found');
              return;
            }
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(data);
          });
        });

        server.listen(0, '127.0.0.1', () => {
          resolve({ server, port: server.address().port });
        });
      });
    }

    app.whenReady().then(async () => {
      const { server, port } = await startServer();

      const win = new BrowserWindow({
        width: 1400,
        height: 900,
        title: 'Mermaid Live Editor',
        webPreferences: {
          nodeIntegration: false,
          contextIsolation: true,
        },
      });

      win.loadURL('http://127.0.0.1:' + port + '/');

      app.on('window-all-closed', () => {
        server.close();
        if (process.platform !== 'darwin') app.quit();
      });
    });
  '';
in
stdenvNoCC.mkDerivation (finalAttrs: {
  inherit pname version src;

  nativeBuildInputs = [
    nodejs
    pnpm
    pnpmConfigHook
    makeWrapper
    copyDesktopItems
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs) pname version src;
    fetcherVersion = 4;
    hash = "sha256-HSjmeXv4fGryiMrjySiRB51yUbds0F+oSrAbL6rJ59A=";
  };

  env = {
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
  };

  buildPhase = ''
    runHook preBuild
    pnpm build
    runHook postBuild
  '';

  desktopItems = [
    (makeDesktopItem {
      name = pname;
      desktopName = "Mermaid Live Editor";
      comment = "Live editor for Mermaid diagrams";
      exec = "mermaid-live-editor %U";
      icon = "mermaid-live-editor";
      categories = [
        "Development"
        "Graphics"
      ];
      mimeTypes = [ "text/plain" ];
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/${pname}/web
    cp -r docs/. $out/lib/${pname}/web/
    cp ${electronMain} $out/lib/${pname}/main.js

    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/${pname} \
      --add-flags "$out/lib/${pname}/main.js"

    runHook postInstall
  '';

  passthru.category = "Desktop applications";

  meta = {
    description = "Live editor for Mermaid diagrams";
    longDescription = ''
      A web-based editor for creating and editing Mermaid diagrams,
      packaged as a desktop application using Electron.
    '';
    homepage = "https://github.com/mermaid-js/mermaid-live-editor";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.linux;
    mainProgram = pname;
  };
})
