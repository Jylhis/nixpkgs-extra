{
  lib,
  pkgs,
  module,
  testLib,
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

  on = evalNixos [
    module
    {
      services.powerPolicy = {
        enable = true;
        batteryStopUnits = [ "heavy.service" ];
        chainUnits = [ "limiter.service" ];
      };
    }
  ];
  off = evalNixos [ module ];
  withProfiles = evalNixos [
    module
    {
      services.powerPolicy = {
        enable = true;
        profiles = {
          full = "performance";
          weak = "balanced";
          battery = "power-saver";
        };
      };
      services.power-profiles-daemon.enable = true;
    }
  ];
  profilesWithoutDaemon = evalNixos [
    module
    {
      services.powerPolicy = {
        enable = true;
        profiles = {
          full = "performance";
          weak = "balanced";
          battery = "power-saver";
        };
      };
    }
  ];

  cases = runCases "nixos-power-policy-eval" {
    off-by-default = expect (!(off.systemd.services ? power-policy)) "service present when disabled";
    enabled = allOf [
      (noFailedAssertions on)
      (expect (on.systemd.services ? power-policy) "service missing")
      (expect (on.systemd.timers ? power-policy) "timer missing")
      (expect (
        on.systemd.services.power-policy.onSuccess == [ "limiter.service" ]
      ) "chainUnits not wired")
      (expect (
        on.systemd.services.heavy.serviceConfig ? ExecCondition
      ) "batteryStopUnits lack an ExecCondition")
    ];
    profile-unit = allOf [
      (noFailedAssertions withProfiles)
      (expect (withProfiles.systemd.services ? power-policy-profile) "profile unit missing")
      (expect (!(on.systemd.services ? power-policy-profile)) "profile unit without profiles")
    ];
    profiles-need-daemon = expect (
      testLib.failedAssertions profilesWithoutDaemon != [ ]
    ) "profiles without power-profiles-daemon did not fail an assertion";
  };

  script = import ./power-policy-script.nix { inherit lib pkgs; } {
    batteryDebounceSec = 90;
    drainWindowSec = 300;
    drainThresholdUwh = 1000000;
    intervalSec = 60;
    stopUnits = [ "heavy.service" ];
    gpuMaxClockMhz = null;
    nvidiaSmi = null;
    profiles = null;
    powerProfilesCtl = null;
  };
in
# One check: the eval cases gate the script behaviour test.
pkgs.runCommand "nixos-power-policy"
  {
    nativeBuildInputs = [ pkgs.coreutils ];
    inherit cases;
  }
  ''
    export PATH=$PATH:${pkgs.coreutils}/bin
    root=$PWD/fake
    mkdir -p "$root/sys/AC" "$root/sys/BAT0" "$root/bin"
    echo Mains > "$root/sys/AC/type"
    echo Battery > "$root/sys/BAT0/type"

    # Records the systemctl calls instead of running them.
    cat > "$root/bin/systemctl" <<SH
    #!${pkgs.runtimeShell}
    echo "\$*" >> "$root/systemctl.log"
    SH
    chmod +x "$root/bin/systemctl"

    export POWER_SUPPLY_DIR="$root/sys"
    export STATE_DIR="$root/state"
    export SYSTEMCTL="$root/bin/systemctl"

    run() { # now ac energy
      NOW=$1 ; echo "$2" > "$root/sys/AC/online"; echo "$3" > "$root/sys/BAT0/energy_now"
      NOW=$1 ${script} >> "$root/out.log"
    }
    state() { cat "$STATE_DIR/state"; }
    expect_state() {
      if [ "$(state)" != "$1" ]; then
        echo "expected state $1, got $(state)" >&2
        cat "$root/out.log" >&2
        exit 1
      fi
    }

    # No supplies at all: nothing to manage.
    mkdir -p "$root/empty"
    POWER_SUPPLY_DIR="$root/empty" ${script}
    expect_state full

    # AC online, battery holds: full.
    run 1000 1 50000000
    expect_state full
    run 1060 1 50000000
    expect_state full

    # Energy drops by >= 1 Wh within the window: weak (and sticky).
    run 1120 1 48500000
    expect_state weak
    run 1180 1 48500000
    expect_state weak

    # Unplug: still weak until the debounce has elapsed, then battery and the
    # stop units are stopped.
    run 1240 0 48000000
    expect_state weak
    run 1300 0 48000000
    expect_state weak
    run 1340 0 48000000
    expect_state battery
    grep -q -- '--no-block stop heavy.service' "$root/systemctl.log"

    # AC returns: back to full and the stop units start again.
    run 1400 1 48000000
    expect_state full
    grep -q -- '--no-block start heavy.service' "$root/systemctl.log"

    touch $out
  ''
