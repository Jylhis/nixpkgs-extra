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

  backups = {
    services.borgbackup.jobs = {
      daily = {
        paths = [ "/var/lib" ];
        repo = "/srv/borg";
        encryption.mode = "none";
        startAt = "daily";
      };
      weekly = {
        paths = [ "/var/lib" ];
        repo = "/srv/borg";
        encryption.mode = "none";
        startAt = "weekly";
      };
      manual = {
        paths = [ "/var/lib" ];
        repo = "/srv/borg";
        encryption.mode = "none";
        startAt = [ ];
      };
    };
    services.restic.backups.nightly = {
      repository = "/srv/restic";
      passwordFile = "/run/restic-password";
      paths = [ "/var/lib" ];
      timerConfig.OnCalendar = "weekly";
    };
    services.restic.backups.ondemand = {
      repository = "/srv/restic2";
      passwordFile = "/run/restic-password";
      paths = [ "/var/lib" ];
      timerConfig = null;
    };
  };

  off = evalNixos [
    module
    backups
  ];
  on = evalNixos [
    module
    backups
    {
      services.backupFreshness = {
        enable = true;
        extraUnits."custom.service".maxAgeDays = 3;
      };
    }
  ];
  borgOnly = evalNixos [
    module
    backups
    {
      services.backupFreshness = {
        enable = true;
        restic = false;
        dailyMaxAgeDays = 1;
      };
    }
  ];
  empty = evalNixos [
    module
    { services.backupFreshness.enable = true; }
  ];
  age =
    config: unit:
    (lib.findFirst (u: u.unit == unit) {
      maxAge = null;
    } config.services.backupFreshness.monitoredUnits).maxAge;
  cases = runCases "nixos-backup-freshness-eval" {
    inert-by-default = allOf [
      (expect (!off.systemd.services ? backup-freshness-check) "service present without enable")
      (expect (!off.systemd.timers ? backup-freshness-check) "timer present without enable")
    ];
    discovers-jobs-with-limits = allOf [
      (expect (age on "borgbackup-job-daily.service" == 2 * 86400) "daily borg job limit")
      (expect (age on "borgbackup-job-weekly.service" == 10 * 86400) "weekly borg job limit")
      (expect (age on "restic-backups-nightly.service" == 10 * 86400) "weekly restic job limit")
      (expect (age on "custom.service" == 3 * 86400) "extra unit limit")
      (expect (age on "borgbackup-job-manual.service" == null) "unscheduled borg job monitored")
      (expect (age on "restic-backups-ondemand.service" == null) "unscheduled restic job monitored")
      (expect (
        on.systemd.services ? backup-freshness-check && on.systemd.timers ? backup-freshness-check
      ) "service or timer missing")
      (noFailedAssertions on)
    ];
    toggles-and-limits = allOf [
      (expect (age borgOnly "restic-backups-nightly.service" == null) "restic toggle ignored")
      (expect (age borgOnly "borgbackup-job-daily.service" == 86400) "dailyMaxAgeDays ignored")
    ];
    rechecks-every-timer-run = allOf [
      (expect (
        !(on.systemd.services.backup-freshness-check.serviceConfig ? RemainAfterExit)
      ) "RemainAfterExit keeps the checker active, so later timer events are no-ops")
      (expect (
        on.systemd.services.backup-freshness-check.serviceConfig.Type == "oneshot"
      ) "checker is not a oneshot")
    ];
    survives-reboot = allOf [
      (expect (lib.any (lib.hasSuffix " borgbackup-job-daily.service") (on.systemd.services.borgbackup-job-daily.serviceConfig.ExecStopPost)) "borg job does not record successful completions")
      (expect (lib.any (lib.hasSuffix " restic-backups-nightly.service") (on.systemd.services.restic-backups-nightly.serviceConfig.ExecStopPost)) "restic job does not record successful completions")
      (expect (
        on.systemd.services.custom.serviceConfig.ExecStopPost != [ ]
      ) "extra unit does not record successful completions")
      (expect (
        !(on.systemd.services.borgbackup-job-manual.serviceConfig ? ExecStopPost)
        || !(lib.any (lib.hasSuffix " borgbackup-job-manual.service") on.systemd.services.borgbackup-job-manual.serviceConfig.ExecStopPost)
      ) "unmonitored job records completions")
      (expect (
        on.systemd.services.backup-freshness-check.serviceConfig.StateDirectory == "backup-freshness"
      ) "checker has no state directory")
    ];
    inert-without-jobs = expect (
      !empty.systemd.services ? backup-freshness-check
    ) "service present with nothing to check";
  };
in
# The scripts only exist as built files, so their content is checked in a
# build step next to the eval cases.
pkgs.runCommand "nixos-backup-freshness" { inherit cases; } ''
  check=${on.systemd.services.backup-freshness-check.serviceConfig.ExecStart}
  record=$(echo ${lib.head on.systemd.services.borgbackup-job-daily.serviceConfig.ExecStopPost} | sed 's/^+//; s/ .*//')
  # The checker reads the persisted record the units write.
  grep -q '/var/lib/backup-freshness/' "$check"
  grep -q 'SERVICE_RESULT' "$record"
  grep -q '/var/lib/backup-freshness' "$record"
  touch $out
''
