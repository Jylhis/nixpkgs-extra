# State machine behind services.powerPolicy (default.nix), kept in its
# own file so test.nix can run it against a fake sysfs.
#
# States, written to $STATE_DIR/state:
#   full     AC online and the battery holds
#   weak     AC online but the battery still drained >= drainThresholdUwh
#            within drainWindowSec (the charger cannot keep up); sticky until
#            a debounced unplug, since a flapping dock re-fires Mains events
#   battery  AC offline for >= batteryDebounceSec (immediately at boot)
#
# Units are started/stopped and the power profile is set only on
# transitions, so a manual stop or profile change sticks.
# The GPU clock lock is re-applied on every run while weak because a GPU
# reset, suspend or the last client exiting drops it.
{ lib, pkgs }:
{
  batteryDebounceSec,
  drainWindowSec,
  drainThresholdUwh,
  intervalSec,
  stopUnits,
  gpuMaxClockMhz,
  nvidiaSmi,
  profiles,
  powerProfilesCtl,
}:
let
  profileOf = state: if profiles == null then "" else profiles.${state};
in
pkgs.writeShellScript "power-policy" ''
  PATH=${lib.makeBinPath [ pkgs.coreutils ]}
  ps_dir=''${POWER_SUPPLY_DIR:-/sys/class/power_supply}
  state_dir=''${STATE_DIR:-/run/power-policy}
  now=''${NOW:-$(date +%s)}
  systemctl=''${SYSTEMCTL:-${pkgs.systemd}/bin/systemctl}
  nvidia_smi=''${NVIDIA_SMI:-${toString nvidiaSmi}}
  max_clock=${toString gpuMaxClockMhz}
  stop_units=${lib.escapeShellArg (lib.concatStringsSep " " stopUnits)}
  ppctl=''${POWERPROFILESCTL:-${toString powerProfilesCtl}}

  log() { echo "power-policy: $*"; }

  mains=
  bat=
  for d in "$ps_dir"/*; do
    [ -r "$d/type" ] || continue
    case "$(cat "$d/type")" in
      Mains) [ -n "$mains" ] || mains=$d ;;
      Battery) case "''${d##*/}" in BAT*) [ -n "$bat" ] || bat=$d ;; esac ;;
    esac
  done

  mkdir -p "$state_dir"
  samples=$state_dir/samples
  prev=$(cat "$state_dir/state" 2>/dev/null)

  # Desktop, or a laptop without readable supplies: nothing to manage.
  if [ -z "$mains" ] || [ -z "$bat" ]; then
    [ "$prev" = full ] || log "no mains or battery supply; state=full"
    echo full > "$state_dir/state"
    exit 0
  fi

  # Unreadable means online: never stop units on a guess.
  ac=$(cat "$mains/online" 2>/dev/null || echo 1)
  energy=$(cat "$bat/energy_now" 2>/dev/null)

  # Suspend or a clock jump: old samples no longer describe a drain rate.
  last_ts=$(tail -n 1 "$samples" 2>/dev/null | cut -d ' ' -f 1)
  if [ -n "$last_ts" ] && { [ "$now" -lt "$last_ts" ] || [ $((now - last_ts)) -gt $((3 * ${toString intervalSec})) ]; }; then
    log "gap since last sample ($last_ts -> $now); resetting drain window"
    : > "$samples"
    rm -f "$state_dir/gpu_locked"
  fi

  next=$prev
  drain=
  if [ "$ac" = 1 ]; then
    rm -f "$state_dir/offline_since"
    case "$prev" in
      "" | battery)
        next=full
        : > "$samples"
        ;;
    esac

    if [ -n "$energy" ]; then
      echo "$now $energy" >> "$samples"
      cutoff=$((now - ${toString drainWindowSec}))
      peak=0
      : > "$samples.tmp"
      while read -r ts e; do
        [ "$ts" -ge "$cutoff" ] || continue
        echo "$ts $e" >> "$samples.tmp"
        [ "$e" -gt "$peak" ] && peak=$e
      done < "$samples"
      mv "$samples.tmp" "$samples"
      drain=$((peak - energy))
      if [ "$next" = full ] && [ "$drain" -ge ${toString drainThresholdUwh} ]; then
        next=weak
      fi
    fi
  else
    [ -s "$state_dir/offline_since" ] || echo "$now" > "$state_dir/offline_since"
    offline_since=$(cat "$state_dir/offline_since")
    if [ -z "$prev" ] || [ $((now - offline_since)) -ge ${toString batteryDebounceSec} ]; then
      next=battery
    fi
  fi

  echo "$next" > "$state_dir/state"
  log "ac=$ac energy=''${energy:-?} drain=''${drain:-?} state=$next"

  if [ "$next" != "$prev" ]; then
    log "transition ''${prev:-none} -> $next"
    # --no-block: the units are ordered after power-policy.service, so a
    # blocking start from inside it would deadlock.
    for u in $stop_units; do
      if [ "$next" = battery ]; then
        "$systemctl" --no-block stop "$u" || log "stopping $u failed"
      elif [ "$prev" = battery ]; then
        "$systemctl" --no-block start "$u" || log "starting $u failed"
      fi
    done

    case "$next" in
      full) profile=${profileOf "full"} ;;
      weak) profile=${profileOf "weak"} ;;
      battery) profile=${profileOf "battery"} ;;
    esac
    # Before the daemon is up (first boot run), power-policy-profile.service
    # applies the profile once it starts; calling it here would wait on D-Bus
    # activation of a daemon ordered after multi-user.target.
    if [ -n "$profile" ] && [ -n "$ppctl" ] \
      && "$systemctl" is-active --quiet power-profiles-daemon.service; then
      "$ppctl" set "$profile" || log "setting profile $profile failed"
    fi
  fi

  if [ -n "$nvidia_smi" ] && [ -n "$max_clock" ]; then
    if [ "$next" = weak ]; then
      if "$nvidia_smi" -lgc "210,$max_clock" > /dev/null; then
        touch "$state_dir/gpu_locked"
      else
        log "locking GPU clocks failed"
      fi
    elif [ -e "$state_dir/gpu_locked" ] || [ "$prev" = weak ]; then
      if "$nvidia_smi" -rgc > /dev/null; then
        rm -f "$state_dir/gpu_locked"
      else
        log "resetting GPU clocks failed"
      fi
    fi
  fi

  exit 0
''
