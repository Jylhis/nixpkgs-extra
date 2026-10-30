# Power-source policy for laptops: classify the supply as full, weak (on AC but
# the battery still drains, e.g. a 90 W USB-C dock under load) or battery, and
# act on it. The state machine lives in ./power-policy-script.nix; the state
# file is read by other units (chainUnits, ExecCondition below).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.powerPolicy;
  inherit (lib) mkOption types;

  script = import ./power-policy-script.nix { inherit lib pkgs; } {
    inherit (cfg)
      batteryDebounceSec
      drainWindowSec
      intervalSec
      profiles
      ;
    powerProfilesCtl = if cfg.profiles == null then null else powerProfilesCtl;
    stopUnits = cfg.batteryStopUnits;
    drainThresholdUwh = builtins.floor (cfg.drainThresholdWh * 1000000);
    gpuMaxClockMhz = cfg.gpu.maxClockMhz;
    inherit (cfg.gpu) nvidiaSmi;
  };

  # Skip (exit 1, not a failure) on battery. Before the first policy run, fall
  # back to any online Mains supply; no Mains supply at all means run.
  notOnBattery = pkgs.writeShellScript "power-policy-not-on-battery" ''
    state=$(${pkgs.coreutils}/bin/cat ${cfg.stateDir}/state 2>/dev/null)
    if [ -n "$state" ]; then
      [ "$state" != battery ]
      exit
    fi
    mains=0
    for d in /sys/class/power_supply/*; do
      [ "$(${pkgs.coreutils}/bin/cat "$d/type" 2>/dev/null)" = Mains ] || continue
      mains=1
      [ "$(${pkgs.coreutils}/bin/cat "$d/online" 2>/dev/null)" = 1 ] && exit 0
    done
    [ "$mains" = 0 ]
  '';

  start = "${pkgs.systemd}/bin/systemctl --no-block start power-policy.service";

  powerProfilesCtl = "${config.services.power-profiles-daemon.package}/bin/powerprofilesctl";

  # Boot catch-up for the profile the policy script sets on transitions: its
  # first run usually beats power-profiles-daemon, which orders itself after
  # multi-user.target.
  applyProfile = pkgs.writeShellScript "power-policy-profile" ''
    case "$(${pkgs.coreutils}/bin/cat ${cfg.stateDir}/state 2>/dev/null)" in
      full) profile=${cfg.profiles.full} ;;
      weak) profile=${cfg.profiles.weak} ;;
      battery) profile=${cfg.profiles.battery} ;;
      *) exit 0 ;;
    esac
    exec ${powerProfilesCtl} set "$profile"
  '';
in
{
  options.services.powerPolicy = {
    enable = lib.mkEnableOption "the full/weak/battery power-source policy";

    stateDir = mkOption {
      type = types.str;
      default = "/run/power-policy";
      readOnly = true;
      description = "Directory holding the `state` file (full, weak or battery) other units read.";
    };

    intervalSec = mkOption {
      type = types.ints.positive;
      default = 60;
      description = "Seconds between timer-driven runs; Mains udev events and resume trigger extra runs.";
    };

    batteryDebounceSec = mkOption {
      type = types.ints.unsigned;
      default = 90;
      description = "AC must read offline this long before the state becomes battery, so dock flaps do not count.";
    };

    drainWindowSec = mkOption {
      type = types.ints.positive;
      default = 300;
      description = "Window over which battery drain is measured while on AC.";
    };

    drainThresholdWh = mkOption {
      type = types.numbers.positive;
      default = 1.0;
      description = ''
        Drop from the window's peak energy that marks the charger as weak. The
        default over 300 s is a sustained deficit of about 12 W.
      '';
    };

    batteryStopUnits = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "inference-server.service" ];
      description = ''
        Service units stopped on entering battery and started again when AC
        returns. Each also gets an ExecCondition so it never starts on battery.
      '';
    };

    chainUnits = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "cpu-power-limit.service" ];
      description = ''
        Units started after every successful policy run (`OnSuccess=`), so
        they read a freshly written state file. Order them `after`
        power-policy.service too, so a boot-time start waits for the state.
      '';
    };

    gpu = {
      maxClockMhz = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Upper GPU clock lock (`nvidia-smi -lgc`) while weak; null leaves clocks alone.";
      };

      nvidiaSmi = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "nvidia-smi binary used for the clock lock.";
      };
    };

    profiles = mkOption {
      type = types.nullOr (
        types.submodule {
          options = lib.genAttrs [ "full" "weak" "battery" ] (
            state:
            mkOption {
              type = types.enum [
                "performance"
                "balanced"
                "power-saver"
              ];
              description = "power-profiles-daemon profile while the state is ${state}.";
            }
          );
        }
      );
      default = null;
      example = {
        full = "performance";
        weak = "balanced";
        battery = "balanced";
      };
      description = ''
        power-profiles-daemon profile per state, set on every transition and
        whenever the daemon starts. A manual change sticks until the next
        transition. null leaves the profile alone.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.profiles != null -> config.services.power-profiles-daemon.enable;
        message = "services.powerPolicy.profiles needs services.power-profiles-daemon.enable.";
      }
    ];

    systemd = {
      tmpfiles.rules = [ "d ${cfg.stateDir} 0755 root root -" ];

      services = {
        power-policy = {
          description = "Classify the power source (full, weak, battery)";
          wantedBy = [ "multi-user.target" ];
          # Triggered by every Mains event; a flapping dock fires many a minute.
          startLimitIntervalSec = 0;
          environment.STATE_DIR = cfg.stateDir;
          onSuccess = cfg.chainUnits;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = script;
          };
        };
      }
      // lib.optionalAttrs (cfg.profiles != null) {
        # Re-applies on every daemon (re)start, so no RemainAfterExit. Hung off
        # the daemon rather than multi-user.target: the daemon orders itself
        # after that target, so wantedBy there would close an ordering cycle.
        power-policy-profile = {
          description = "Apply the power profile for the current power-policy state";
          wantedBy = [ "power-profiles-daemon.service" ];
          after = [
            "power-profiles-daemon.service"
            "power-policy.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = applyProfile;
          };
        };
      }
      // lib.genAttrs (map (lib.removeSuffix ".service") cfg.batteryStopUnits) (_: {
        after = [ "power-policy.service" ];
        serviceConfig.ExecCondition = notOnBattery;
      });

      timers.power-policy = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "${toString cfg.intervalSec}s";
          AccuracySec = "5s";
        };
      };
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${start}"
    '';
    powerManagement.resumeCommands = start;
  };
}
