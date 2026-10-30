# NixOS wrapper around services.alloy that ships metrics, logs, traces and
# profiles to Grafana Cloud from one declarative option tree.
#
# The option schema and the Alloy config generator live in lib/grafana-cloud.
# The access token is read from `environmentFile` at run time, so nothing
# secret lands in the Nix store.
{
  config,
  lib,
  pkgs,
  extraLib,
  ...
}:
let
  gc = extraLib.grafanaCloud;
  cfg = config.services.grafanaCloud;
  smart = cfg.metrics.smartctl;
  smartEnabled = cfg.metrics.enable && smart.enable;
in
{
  options.services.grafanaCloud = gc.mkOptions { inherit pkgs; };

  config = lib.mkIf cfg.enable {
    services.alloy = {
      enable = true;
      inherit (cfg) package environmentFile;
      configPath = "/etc/alloy";
    };

    environment.etc."alloy/config.alloy".text = gc.mkAlloyConfig cfg;

    # When smartctl is requested, run the upstream exporter and add it as a
    # local scrape target.
    services.prometheus.exporters.smartctl = lib.mkIf smartEnabled {
      enable = true;
      inherit (smart)
        listenAddress
        devices
        maxInterval
        port
        ;
    };

    services.grafanaCloud.metrics.extraScrapeTargets = lib.mkIf smartEnabled [
      {
        address = "${smart.listenAddress}:${toString smart.port}";
        job = "smartctl";
      }
    ];

    assertions = gc.mkAssertions "services.grafanaCloud" cfg;
  };
}
