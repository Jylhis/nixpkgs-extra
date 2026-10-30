{
  lib,
  pkgs,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalHome
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  stub = pkgs.writeShellScriptBin "ocr" "true";

  off = evalHome [ module ];

  noPackage = evalHome [
    module
    { programs.open-code-review.enable = true; }
  ];

  on = evalHome [
    module
    {
      programs.open-code-review = {
        enable = true;
        package = stub;
        settings.model = "demo";
        telemetry = {
          enable = true;
          endpoint = "http://otlp.example.org:6006";
          headersFile = "/run/otlp-headers.json";
        };
        viewer = {
          enable = true;
          port = 5999;
          allowedHosts = [ "ocr.example.org" ];
        };
      };
    }
  ];

  viewer = on.systemd.user.services.ocr-viewer.Service;
  execStart = lib.concatStringsSep " " (lib.toList viewer.ExecStart);
in
runCases "home-open-code-review" {
  off-by-default = allOf [
    (expect (!off.programs.open-code-review.enable) "enabled without enable = true")
    (noFailedAssertions off)
    (expect (!(off.systemd.user.services ? ocr-viewer)) "viewer unit without enable")
  ];
  # Home Manager throws its failed assertions on any read of the config.
  package-null-asserts = expect (
    !(builtins.tryEval noPackage.programs.open-code-review.enable).success
  ) "enabling without a package does not assert";
  stub-package = allOf [
    (noFailedAssertions on)
    (expect (builtins.match ".* --addr 127.0.0.1:5999 .*" execStart != null) "viewer port not rendered")
    (expect (
      viewer.Environment == [ "OCR_VIEWER_ALLOWED_HOSTS=ocr.example.org" ]
    ) "allowed hosts not rendered")
    (expect (on.home.activation ? openCodeReviewConfig) "settings merge activation missing")
  ];
  no-settings-no-activation = expect (
    !(evalHome [
      module
      {
        programs.open-code-review = {
          enable = true;
          package = stub;
        };
      }
    ]).home.activation
      ? openCodeReviewConfig
  ) "activation entry without settings";
}
