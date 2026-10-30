# Watch the mirrored-boot ESPs for two silent failures:
#
#   1. An ESP is not mounted: install-grub.pl then writes into the root
#      filesystem at the mountpoint path. `nofail` makes this quiet.
#   2. An ESP is mounted but stale: booting that disk lands on an older
#      generation than the system profile.
#
# No mail transport is assumed: the signal is a failed unit plus a journald
# line. There is no enable option; the module is inert unless
# `boot.loader.grub.mirroredBoots` is non-empty.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  esps = map (b: b.path) config.boot.loader.grub.mirroredBoots;

  checkScript = pkgs.writeShellApplication {
    name = "boot-mirror-check";
    runtimeInputs = [
      pkgs.util-linux # mountpoint
      pkgs.coreutils # readlink, df, tail, tr
      pkgs.gnugrep
    ];
    text = ''
      failed=0

      # The system profile, not /run/current-system: `nixos-rebuild boot`
      # leaves the running system alone, which would read as divergence.
      want=$(readlink -f /nix/var/nix/profiles/system)

      for esp in ${lib.escapeShellArgs esps}; do
        if ! mountpoint -q "$esp"; then
          echo "boot-mirror: $esp is NOT a mountpoint -- bootloader writes are landing on the root filesystem, and the real ESP is not being updated" >&2
          failed=1
          continue
        fi

        if ! grep -qF "$want/init" "$esp/grub/grub.cfg"; then
          echo "boot-mirror: $esp/grub/grub.cfg does not reference the current system profile ($want) -- this ESP is stale and would boot an older generation" >&2
          failed=1
        fi

        use=$(df --output=pcent "$esp" | tail -1 | tr -dc '0-9')
        if [ "$use" -ge 85 ]; then
          echo "boot-mirror: $esp is ''${use}% full -- a bootloader install may be truncated" >&2
          failed=1
        fi
      done

      if [ "$failed" -ne 0 ]; then
        exit 1
      fi
      echo "boot-mirror: ${toString (builtins.length esps)} ESP(s) mounted and current"
    '';
  };
in
{
  config = lib.mkIf (config.boot.loader.grub.mirroredBoots != [ ]) {
    systemd.services.boot-mirror-check = {
      description = "Check mirrored-boot ESPs are mounted and current";
      # Also run once per boot, when the ESP mounts matter most.
      after = [ "local-fs.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ checkScript ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe checkScript;

        # No DynamicUser: the ESPs are root-owned with umask=0077.
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

    systemd.timers.boot-mirror-check = {
      description = "Periodically check mirrored-boot ESPs";
      wantedBy = [ "timers.target" ];
      # Stay clear of night-time maintenance jobs (SMART, GC, scrubs).
      timerConfig = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
        RandomizedDelaySec = "1h";
      };
    };
  };
}
