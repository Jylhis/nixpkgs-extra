# Home Manager wrapper: runs Grafana Alloy as a systemd user service that
# ships telemetry to Grafana Cloud. Home Manager has no Alloy module, so the
# unit is defined here. Linux only.
#
# Per-user agents cannot read the system journal, so journal forwarding
# defaults to off. The access token is read from `environmentFile` by systemd
# at run time, so nothing secret lands in the Nix store.
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

  configFile = "${config.xdg.configHome}/alloy/config.alloy";
in
{
  options.services.grafanaCloud = gc.mkOptions {
    inherit pkgs;
    # A workstation usually wants a local OTLP collector for traces; host
    # metrics and logs stay opt-in.
    defaults = {
      metricsEnable = false;
      logsEnable = false;
      tracesEnable = true;
      nodeExporter = false;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = gc.mkAssertions "services.grafanaCloud" cfg ++ [
      {
        assertion = pkgs.stdenv.hostPlatform.isLinux;
        message = "services.grafanaCloud is only supported on Linux (systemd user services).";
      }
    ];

    services.grafanaCloud.logs.journal = lib.mkDefault false;

    xdg.configFile."alloy/config.alloy".text = gc.mkAlloyConfig cfg;

    systemd.user.services.grafana-cloud-alloy = {
      Unit = {
        Description = "Grafana Alloy (user), Grafana Cloud agent";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
        X-Restart-Triggers = [ "${config.xdg.configFile."alloy/config.alloy".source}" ];
      };
      Service = {
        ExecStart = "${lib.getExe cfg.package} run --storage.path=%S/alloy ${configFile}";
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ (toString cfg.environmentFile) ];
        StateDirectory = "alloy";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
