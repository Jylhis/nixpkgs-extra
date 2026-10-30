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

  envFile = "/run/grafana-cloud.env";

  off = evalHome [ module ];

  on = evalHome [
    module
    {
      services.grafanaCloud = {
        enable = true;
        environmentFile = envFile;
        traces = {
          endpoint = "https://otlp.example.org/otlp";
          user = "333";
        };
      };
    }
  ];

  labelled = evalHome [
    module
    {
      services.grafanaCloud = {
        enable = true;
        environmentFile = envFile;
        environment = "test";
        externalLabels.site = "lab";
        traces = {
          endpoint = "https://otlp.example.org/otlp";
          user = "333";
        };
      };
    }
  ];
  labelledConfig = labelled.xdg.configFile."alloy/config.alloy".text;

  # Home Manager throws on failed assertions as soon as the config is read,
  # so judge them on the generator's output for an unconfigured tree.
  base = off.services.grafanaCloud;
  unconfigured = extraLib.grafanaCloud.mkAssertions "services.grafanaCloud" (
    base
    // {
      traces = base.traces // {
        enable = true;
      };
    }
  );

  config = on.xdg.configFile."alloy/config.alloy".text;
  unit = on.systemd.user.services.grafana-cloud-alloy;
  has = lib.hasInfix;

  cases = runCases "home-grafana-cloud" {
    off-by-default = allOf [
      (expect (!off.services.grafanaCloud.enable) "enabled without enable = true")
      (expect (!(off.systemd.user.services ? grafana-cloud-alloy)) "unit defined while disabled")
      (noFailedAssertions off)
    ];
    workstation-defaults = allOf [
      (expect (!on.services.grafanaCloud.metrics.enable) "metrics on by default")
      (expect (!on.services.grafanaCloud.logs.enable) "logs on by default")
      (expect on.services.grafanaCloud.traces.enable "traces off by default")
      (expect (!on.services.grafanaCloud.logs.journal) "journal forwarding on for a user agent")
    ];
    user-service = allOf [
      (noFailedAssertions on)
      (expect (unit.Service.EnvironmentFile == [ envFile ]) "EnvironmentFile not set")
      (expect (has "run --storage.path=" (toString unit.Service.ExecStart)) "ExecStart")
      (expect (unit.Install.WantedBy == [ "default.target" ]) "not wanted by default.target")
    ];
    config-rendered = allOf [
      (expect (has "otelcol.receiver.otlp" config) "traces block")
      (expect (has ''password = sys.env("GC_TOKEN")'' config) "token not read from the environment")
      (expect (!has "prometheus.remote_write" config) "metrics block rendered while disabled")
    ];
    traces-unlabelled = allOf [
      (expect (!has "otelcol.processor.transform" config) "processor rendered without labels")
      (expect (has "traces = [otelcol.exporter.otlphttp.gc.input]" config) "receiver not wired to exporter")
    ];
    traces-labelled = allOf [
      (expect (
        has ''resource.attributes[\"env\"]'' labelledConfig
        && has ''resource.attributes[\"site\"]'' labelledConfig
      ) "trace label attributes")
      (expect (has "traces = [otelcol.processor.transform.labels.input]" labelledConfig) "receiver not routed through the processor")
    ];
    assertions-fire = expect (
      lib.length (lib.filter (a: !a.assertion) unconfigured) >= 2
    ) "enabling without environmentFile and endpoints did not fail";
  };

  alloyConfig = pkgs.writeText "config.alloy" config;
  labelledAlloyConfig = pkgs.writeText "labelled.alloy" labelledConfig;
in
pkgs.runCommand "home-grafana-cloud-validated"
  {
    nativeBuildInputs = [ pkgs.grafana-alloy ];
    inherit cases;
  }
  ''
    alloy validate ${alloyConfig}
    alloy fmt ${alloyConfig} > /dev/null
    alloy validate ${labelledAlloyConfig}
    alloy fmt ${labelledAlloyConfig} > /dev/null
    touch $out
  ''
