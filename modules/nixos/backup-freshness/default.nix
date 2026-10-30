# Make a backup that stopped happening visible. No mail transport is assumed:
# the signal is a failed unit plus a journald line.
#
# Checks "when did this last succeed", not "did the last run fail", to catch
# jobs that stop running: a skipped `ConditionPathIsMountPoint` (unit is
# skipped, `Result` stays `success`) or a timer that was never started.
#
# Jobs are discovered from nixpkgs' `services.borgbackup.jobs` and
# `services.restic.backups` (those with a schedule); other units can be added
# through `extraUnits`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.backupFreshness;

  toList = x: if x == null then [ ] else lib.toList x;

  # Weekly jobs get proportionally more slack. Generous on purpose: this
  # catches "stopped happening", not runs delayed by RandomizedDelaySec.
  maxAgeOf =
    schedules:
    86400 * (if lib.elem "weekly" schedules then cfg.weeklyMaxAgeDays else cfg.dailyMaxAgeDays);

  borgUnits = lib.optionals cfg.borgbackup (
    lib.mapAttrsToList (name: job: {
      unit = "borgbackup-job-${name}.service";
      maxAge = maxAgeOf (toList job.startAt);
    }) (lib.filterAttrs (_: job: toList job.startAt != [ ]) config.services.borgbackup.jobs)
  );

  resticUnits = lib.optionals cfg.restic (
    lib.mapAttrsToList (name: job: {
      unit = "restic-backups-${name}.service";
      maxAge = maxAgeOf (toList (job.timerConfig.OnCalendar or null));
    }) (lib.filterAttrs (_: job: job.timerConfig != null) config.services.restic.backups)
  );

  extraUnits = lib.mapAttrsToList (unit: u: {
    inherit unit;
    maxAge = 86400 * u.maxAgeDays;
  }) cfg.extraUnits;

  units = borgUnits ++ resticUnits ++ extraUnits;

  # systemd keeps execution timestamps in memory only, so after a reboot a
  # weekly job would read as "never completed". Each unit records its own
  # successes here and the checker prefers that.
  stateDir = "/var/lib/backup-freshness";

  recordSuccess = pkgs.writeShellScript "backup-freshness-record" ''
    # ExecStopPost runs after failures and skips too; only a success counts.
    [ "''${SERVICE_RESULT:-}" = success ] || exit 0
    ${pkgs.coreutils}/bin/mkdir -p ${stateDir}
    tmp=$(${pkgs.coreutils}/bin/mktemp ${stateDir}/.tmp.XXXXXX)
    ${pkgs.coreutils}/bin/date +%s > "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" ${stateDir}/"$1"
  '';

  # The `+` prefix runs unsandboxed so ProtectSystem=strict units can still
  # write the state directory. Units defined outside NixOS become drop-ins.
  recorders = lib.listToAttrs (
    map (u: {
      name = lib.removeSuffix ".service" u.unit;
      value.serviceConfig.ExecStopPost = [ "+${recordSuccess} ${u.unit}" ];
    }) units
  );

  specs = map (u: "${u.unit}:${toString u.maxAge}") units;

  checkScript = pkgs.writeShellApplication {
    name = "backup-freshness-check";
    runtimeInputs = [
      pkgs.systemd # systemctl
      pkgs.coreutils # date
    ];
    text = ''
      specs=(${lib.escapeShellArgs specs})
      failed=0
      now=$(date +%s)

      for spec in "''${specs[@]}"; do
        unit=''${spec%:*}
        maxAge=''${spec##*:}

        # Prefer the persisted record; else fall back to systemd's in-memory
        # timestamps. Zero ExecMainExitTimestampMonotonic means never
        # completed (including only ever skipped by a Condition).
        recorded=${stateDir}/$unit
        if [ -r "$recorded" ]; then
          last="@$(cat "$recorded")"
        else
          stamp=$(systemctl show "$unit" -p ExecMainExitTimestampMonotonic --value)
          last=$(systemctl show "$unit" -p InactiveEnterTimestamp --value)

          if [ "$stamp" = "0" ] || [ -z "$last" ]; then
            echo "backup-freshness: $unit has no record of a completed run -- the timer may never have fired, or every run so far was skipped by an unmet condition" >&2
            failed=1
            continue
          fi
        fi

        lastEpoch=$(date -d "$last" +%s 2>/dev/null || echo 0)
        age=$(( now - lastEpoch ))

        if [ "$lastEpoch" -eq 0 ]; then
          echo "backup-freshness: $unit has an unparseable last-run timestamp ($last)" >&2
          failed=1
        elif [ "$age" -gt "$maxAge" ]; then
          echo "backup-freshness: $unit last ran $(( age / 86400 ))d ago, over its $(( maxAge / 86400 ))d limit -- treat the backup as stale" >&2
          failed=1
        else
          result=$(systemctl show "$unit" -p Result --value)
          if [ "$result" != "success" ]; then
            echo "backup-freshness: $unit last run finished with Result=$result" >&2
            failed=1
          fi
        fi
      done

      if [ "$failed" -ne 0 ]; then
        exit 1
      fi
      echo "backup-freshness: ${toString (builtins.length units)} job(s) current"
    '';
  };
in
{
  options.services.backupFreshness = {
    enable = lib.mkEnableOption "a periodic check that every backup job ran and succeeded recently";

    borgbackup = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check every scheduled job in {option}`services.borgbackup.jobs`.";
    };

    restic = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Check every scheduled backup in {option}`services.restic.backups`.";
    };

    dailyMaxAgeDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Days since the last run after which a job not scheduled `weekly` counts as stale.";
    };

    weeklyMaxAgeDays = lib.mkOption {
      type = lib.types.ints.positive;
      default = 10;
      description = "Days since the last run after which a job scheduled `weekly` counts as stale.";
    };

    extraUnits = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options.maxAgeDays = lib.mkOption {
            type = lib.types.ints.positive;
            default = 2;
            description = "Days since the last run after which the unit counts as stale.";
          };
        }
      );
      default = { };
      example = {
        "my-backup.service".maxAgeDays = 7;
      };
      description = "Other oneshot backup units to check, by unit name.";
    };

    monitoredUnits = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      internal = true;
      default = units;
      description = "The units the check covers, with their maximum age in seconds.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 07:00:00";
      description = ''
        When to run the check ({manpage}`systemd.time(7)`). Keep it clear of the
        backup window itself (jobs plus any RandomizedDelaySec).
      '';
    };
  };

  config = lib.mkIf (cfg.enable && units != [ ]) {
    systemd.services = recorders // {
      backup-freshness-check = {
        description = "Check every backup job has run recently and succeeded";
        restartTriggers = [ checkScript ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe checkScript;
          StateDirectory = "backup-freshness";

          # No DynamicUser: querying other services' units needs root.
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          LockPersonality = true;
          SystemCallArchitectures = "native";
        };
      };
    };

    systemd.timers.backup-freshness-check = {
      description = "Periodically check backups are current";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = "30m";
      };
    };
  };
}
