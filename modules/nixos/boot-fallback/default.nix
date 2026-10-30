# Automatic revert to the last known-good NixOS generation on a failed or
# unhealthy boot, for GRUB mirrored-boot machines (see ../boot-mirror).
#
# GRUB rather than systemd-boot bootCounting, which needs UEFI. NixOS has no
# GRUB boot counting, so this builds the Debian/Ubuntu `recordfail` pattern
# on load_env, the next_entry one-shot and `extraConfig`.
#
# State lives in grubenv on both ESPs, namespaced `bootfb_*`:
#   - Every boot arms `bootfb_armed=fail`; only boot-fallback-mark clears it,
#     once healthy. A flag still armed at the next boot means the previous
#     boot never became healthy, and GRUB reverts to `bootfb_last_good`.
#   - A boot that fails the health probe is reverted by the mark service via
#     `grub-reboot` + reboot.
#   - `bootfb_fallback_active` latches once GRUB has flipped, so an unhealthy
#     last-good does not reboot-loop.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.fallbackBoot;
  esps = map (b: b.path) config.boot.loader.grub.mirroredBoots;
  distro = config.system.nixos.distroName;

  grubEditenv = "${pkgs.grub2}/bin/grub-editenv";

  # Runs before the menu (grubenv already load_env'd by the stock header).
  grubSnippet = ''
    # boot-fallback: revert to the last known-good generation if the previous
    # boot armed the flag but never confirmed health.
    if [ "''${bootfb_armed}" = "fail" ]; then
      if [ -n "''${bootfb_last_good}" ]; then
        set default="''${bootfb_last_good}"
        set bootfb_fallback_active=1
        save_env bootfb_fallback_active
      fi
    else
      set bootfb_armed=fail
      save_env bootfb_armed
    fi
  '';

  # Runs once per ESP at activation. `grub-editenv create` truncates, so only
  # create when missing; otherwise every deploy would wipe armed/last_good.
  prepareSnippet = ''
    if [ ! -f @bootPath@/grub/grubenv ]; then
      ${pkgs.coreutils}/bin/mkdir -p @bootPath@/grub
      ${grubEditenv} @bootPath@/grub/grubenv create
    fi
    ${grubEditenv} @bootPath@/grub/grubenv unset bootfb_fallback_active || true
  '';

  markScript = pkgs.writeShellApplication {
    name = "boot-fallback-mark";
    runtimeInputs = [
      pkgs.grub2
      pkgs.systemd
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      settle=${toString cfg.settleSeconds}
      esps=(${lib.escapeShellArgs esps})
      units=(${lib.escapeShellArgs cfg.criticalUnits})

      # Emergency boots never reach here (wanted by multi-user.target); the
      # armed flag covers them. An empty unit list always confirms, so
      # health-based revert is opt-in.
      health_ok() {
        local u
        for u in ''${units[@]+"''${units[@]}"}; do
          systemctl is-active --quiet "$u" || return 1
        done
        return 0
      }

      healthy=1
      for _ in $(seq 1 "$settle"); do
        if health_ok; then healthy=0; break; fi
        sleep 1
      done

      if [ "$healthy" -eq 0 ]; then
        # Record the running generation (/run/booted-system), not the system
        # profile: after a fallback the profile still points at the failed one.
        # The title must match install-grub.pl exactly: "<distro> - All
        # configurations><distro> - Configuration N (YYYY-MM-DD - <version>)".
        booted=$(readlink -f /run/booted-system)
        gen=""
        for link in /nix/var/nix/profiles/system-*-link; do
          [ -e "$link" ] || continue
          [ "$(readlink -f "$link")" = "$booted" ] || continue
          n=''${link##*system-}
          n=''${n%-link}
          if [ -z "$gen" ] || [ "$n" -gt "$gen" ]; then gen=$n; fi
        done
        if [ -z "$gen" ]; then
          echo "boot-fallback: booted system $booted is in no profile generation" \
            "-- confirming health but keeping the previous last-good" >&2
          for esp in "''${esps[@]}"; do
            grub-editenv "$esp/grub/grubenv" set bootfb_armed=ok
            grub-editenv "$esp/grub/grubenv" unset bootfb_fallback_active || true
          done
          exit 0
        fi
        link=/nix/var/nix/profiles/system-"$gen"-link
        date=$(date -d "@$(stat -c %Y "$link")" +%F)
        ver=$(cat "$link/nixos-version")
        entry="${distro} - All configurations>${distro} - Configuration $gen ($date - $ver)"
        for esp in "''${esps[@]}"; do
          grub-editenv "$esp/grub/grubenv" set bootfb_armed=ok bootfb_last_good="$entry"
          grub-editenv "$esp/grub/grubenv" unset bootfb_fallback_active || true
        done
        echo "boot-fallback: generation $gen confirmed healthy"
        exit 0
      fi

      # Unhealthy after the settle window.
      active=$(grub-editenv "''${esps[0]}/grub/grubenv" list | sed -n 's/^bootfb_fallback_active=//p')
      if [ -n "$active" ]; then
        echo "boot-fallback: already on the last-good generation and STILL unhealthy" \
          "-- staying up degraded, not rebooting" >&2
        exit 1
      fi
      target=$(grub-editenv "''${esps[0]}/grub/grubenv" list | sed -n 's/^bootfb_last_good=//p')
      if [ -z "$target" ]; then
        echo "boot-fallback: unhealthy but no known-good generation recorded yet" \
          "-- cannot revert" >&2
        exit 1
      fi
      echo "boot-fallback: generation unhealthy -- reverting to last-good and rebooting" >&2
      for esp in "''${esps[@]}"; do
        grub-reboot --boot-directory="$esp" "$target"
      done
      systemctl reboot
    '';
  };
in
{
  options.boot.fallbackBoot = {
    enable = lib.mkEnableOption (
      "automatic revert to the last known-good NixOS generation on a failed or "
      + "unhealthy boot (GRUB mirrored-boot machines)"
    );

    settleSeconds = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = ''
        Seconds to wait for the critical units to become active before treating
        the boot as unhealthy and reverting.
      '';
    };

    criticalUnits = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "sshd.service"
        "postgresql.service"
      ];
      description = ''
        Units that must be `active` for a boot to count as healthy. List only
        long-running daemons whose `systemctl is-active` is reliably `active`;
        do NOT list socket-activated units (they report `inactive` when idle and
        would trigger a false revert). An empty list disables health-based
        revert but keeps boot-failure revert via the armed flag.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.loader.grub.enable;
        message = "boot.fallbackBoot requires GRUB (grubenv-based boot counting).";
      }
      {
        assertion = esps != [ ];
        message = "boot.fallbackBoot needs boot.loader.grub.mirroredBoots: grubenv state lives on each listed boot path.";
      }
    ];

    boot.loader.grub.extraConfig = grubSnippet;
    boot.loader.grub.extraPrepareConfig = prepareSnippet;

    systemd.services.boot-fallback-mark = {
      description = "Confirm this boot healthy, else revert to the last known-good generation";
      # Run at the end of boot, after the critical services have been started.
      after = [ "multi-user.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ markScript ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe markScript;

        # Less confined than boot-mirror-check: writes grubenv, may reboot.
        ProtectSystem = "strict";
        ReadWritePaths = esps;
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictRealtime = true;
        LockPersonality = true;
        SystemCallArchitectures = "native";
      };
    };
  };
}
