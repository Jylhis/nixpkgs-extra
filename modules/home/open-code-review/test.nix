{
  lib,
  pkgs,
  module,
  testLib,
  extraLib,
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

  wrapperOf = cfg: lib.findFirst (p: (p.name or "") == "ocr") null cfg.home.packages;
  noMetrics = evalHome [
    module
    {
      programs.open-code-review = {
        enable = true;
        package = stub;
        telemetry = {
          enable = true;
          endpoint = "http://otlp.example.org:6006";
          headersFile = "/run/otlp-headers.json";
          metrics.enable = false;
        };
      };
    }
  ];
  noWrapper = evalHome [
    module
    {
      programs.open-code-review = {
        enable = true;
        package = stub;
        installWrapper = false;
        viewer.enable = true;
      };
    }
  ];
  libWrapper = extraLib.openCodeReview.mkWrapper {
    inherit pkgs;
    package = stub;
    telemetry = on.programs.open-code-review.telemetry;
  };
  activationText = on.home.activation.openCodeReviewConfig.data;
  activationFile = pkgs.writeText "ocr-activation" activationText;

  viewer = on.systemd.user.services.ocr-viewer.Service;
  execStart = lib.concatStringsSep " " (lib.toList viewer.ExecStart);
in
(runCases "home-open-code-review" {
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
  wrapper-installed-by-default = expect (wrapperOf on != null) "ocr wrapper missing by default";
  install-wrapper-off = allOf [
    (noFailedAssertions noWrapper)
    (expect (wrapperOf noWrapper == null) "ocr wrapper installed with installWrapper = false")
    (expect (
      noWrapper.home.activation ? openCodeReviewConfig
    ) "settings merge lost without the wrapper")
    (expect (noWrapper.systemd.user.services ? ocr-viewer) "viewer lost without the wrapper")
  ];
  lib-wrapper-is-the-module-wrapper = expect (
    libWrapper.outPath == (wrapperOf on).outPath
  ) "lib.openCodeReview.mkWrapper builds another wrapper than the module";
  metrics-on-by-default = expect (
    !lib.hasInfix "OTEL_METRICS_EXPORTER" (wrapperOf on).text
  ) "metrics exporter set by default";
  metrics-off = expect (lib.hasInfix "export OTEL_METRICS_EXPORTER=none" (wrapperOf noMetrics).text) "OTEL_METRICS_EXPORTER=none missing when metrics are disabled";
  activation-keeps-copy = expect (lib.hasInfix ".hm-settings.json" activationText) "settings copy not referenced";
}).overrideAttrs
  (old: {
    # The prune filter itself: user keys survive, dropped keys go (arrays
    # whole), objects emptied by the prune go, and a user key keeps its object.
    buildCommand = old.buildCommand + ''

      pruneJq=$(grep -o "${builtins.storeDir}/[^ ]*ocr-prune.jq" ${activationFile})
      cur='{"a":1,"b":{"c":2},"d":{"e":{"f":1}},"l":[1,2],"p":{"x":1,"u":2},"user":3}'
      old='{"a":1,"b":{"c":2},"d":{"e":{"f":1}},"l":[1,2],"p":{"x":1}}'
      echo '{"a":1}' > new.json
      got=$(echo "$cur" | ${lib.getExe pkgs.jq} -c --argjson old "$old" --slurpfile new new.json \
        -f "$pruneJq")
      want='{"a":1,"p":{"u":2},"user":3}'
      [ "$got" = "$want" ] || { echo "prune: got $got, want $want" >&2; exit 1; }
      got=$(echo "$cur" | ${lib.getExe pkgs.jq} -c --argjson old '{}' --slurpfile new new.json \
        -f "$pruneJq")
      want='{"a":1,"b":{"c":2},"d":{"e":{"f":1}},"l":[1,2],"p":{"x":1,"u":2},"user":3}'
      [ "$got" = "$want" ] || { echo "no copy: got $got, want $want" >&2; exit 1; }
    '';
  })
