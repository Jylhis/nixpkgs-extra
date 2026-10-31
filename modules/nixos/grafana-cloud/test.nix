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
    evalNixos
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  envFile = "/run/grafana-cloud.env";

  off = evalNixos [ module ];

  full = evalNixos [
    module
    {
      services.grafanaCloud = {
        enable = true;
        environmentFile = envFile;
        environment = "test";
        externalLabels.site = "lab";
        metrics = {
          endpoint = "https://prom.example.org/api/prom/push";
          user = "111";
          smartctl.enable = true;
          extraScrapeTargets = [
            {
              address = "127.0.0.1:9100";
              job = "extra";
              labels.tier = "a";
            }
          ];
        };
        logs = {
          endpoint = "https://loki.example.org/loki/api/v1/push";
          user = "222";
          files = [
            {
              path = "/var/log/*.log";
              labels.app = "demo";
            }
          ];
        };
        traces = {
          enable = true;
          endpoint = "https://otlp.example.org/otlp";
          user = "333";
        };
        profiles = {
          enable = true;
          endpoint = "https://pyro.example.org";
          user = "444";
        };
        extraConfig = "// extra";
      };
    }
  ];

  # Home Manager throws on failed assertions as soon as the config is read,
  # so judge them on the generator's output for an unconfigured tree.
  base = off.services.grafanaCloud;
  unconfigured = extraLib.grafanaCloud.mkAssertions "services.grafanaCloud" base;

  config = full.environment.etc."alloy/config.alloy".text;
  has = lib.hasInfix;

  cases = runCases "nixos-grafana-cloud" {
    off-by-default = allOf [
      (expect (!off.services.grafanaCloud.enable) "enabled without enable = true")
      (expect (!off.services.alloy.enable) "alloy enabled while grafanaCloud is off")
      (noFailedAssertions off)
    ];
    no-personal-defaults = allOf [
      (expect (off.services.grafanaCloud.environment == null) "environment label has a default")
      (expect (off.services.grafanaCloud.metrics.endpoint == null) "metrics endpoint has a default")
      (expect (off.services.grafanaCloud.metrics.user == null) "metrics user has a default")
      (expect (off.services.grafanaCloud.environmentFile == null) "environmentFile has a default")
    ];
    alloy-wired = allOf [
      (noFailedAssertions full)
      (expect full.services.alloy.enable "alloy not enabled")
      (expect (full.services.alloy.environmentFile == envFile) "environmentFile not passed to alloy")
      (expect (full.services.alloy.package == pkgs.grafana-alloy) "package default")
    ];
    config-rendered = allOf [
      (expect (has ''url = "https://prom.example.org/api/prom/push"'' config) "metrics url")
      (expect (has ''username = "111"'' config) "metrics user")
      (expect (has ''password = sys.env("GC_TOKEN")'' config) "token not read from the environment")
      (expect (has ''env = "test"'' config && has ''site = "lab"'' config) "labels")
      (expect (has ''__path__ = "/var/log/*.log"'' config) "log file target")
      (expect (has "loki.source.journal" config) "journal source")
      (expect (has "otelcol.exporter.otlphttp" config && has ''username = "333"'' config) "traces")
      (expect (has "pyroscope.write" config && has ''username = "444"'' config) "profiles")
      (expect (has "// extra" config) "extraConfig")
      (expect (!has envFile config) "environment file path leaked into the config")
    ];
    traces-labelled = allOf [
      (expect (has ''otelcol.processor.transform "labels"'' config) "label processor missing")
      (expect (
        has ''resource.attributes[\"env\"]'' config && has ''resource.attributes[\"site\"]'' config
      ) "trace label attributes")
      (expect (has "traces = [otelcol.processor.transform.labels.input]" config) "receiver not routed through the processor")
    ];
    smartctl = allOf [
      (expect full.services.prometheus.exporters.smartctl.enable "smartctl exporter not enabled")
      (expect (has ''job = "smartctl"'' config) "smartctl scrape target missing")
    ];
    assertions-fire = expect (
      lib.length (lib.filter (a: !a.assertion) unconfigured) >= 2
    ) "enabling without environmentFile and endpoints did not fail";
  };

  alloyConfig = pkgs.writeText "config.alloy" config;
in
# The generated config must also parse as Alloy.
pkgs.runCommand "nixos-grafana-cloud-validated"
  {
    nativeBuildInputs = [ pkgs.grafana-alloy ];
    inherit cases;
  }
  ''
    alloy validate ${alloyConfig}
    alloy fmt ${alloyConfig} > /dev/null
    touch $out
  ''
