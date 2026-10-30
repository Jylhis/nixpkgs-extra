# VM integration test for the boot-mirror module.
#
# Runs boot-mirror-check against every branch it claims to detect. A tmpfs
# stands in for each ESP: the script only reads mountpoint status, grub.cfg
# and df output, and failures can be produced on demand.
#
# The script is invoked directly to assert output per branch; the healthy case
# also goes through the systemd unit to prove the hardening allows the reads.
{ pkgs, module, ... }:
pkgs.testers.runNixOSTest {
  name = "boot-mirror-vm";

  nodes.machine = {
    imports = [ module ];

    # The module keys off a non-empty mirroredBoots (reads only `.path`).
    # GRUB stays disabled: installing it would not exercise the detection.
    boot.loader.grub = {
      enable = false;
      mirroredBoots = [
        {
          path = "/boot";
          devices = [ "/dev/vda" ];
        }
        {
          path = "/boot-efi2";
          devices = [ "/dev/vdb" ];
        }
      ];
    };
  };

  testScript =
    { nodes, ... }:
    ''
      check = "${nodes.machine.systemd.services.boot-mirror-check.serviceConfig.ExecStart}"

      machine.start()
      machine.wait_for_unit("multi-user.target")

      # The module compares against the system profile; ensure one exists.
      machine.succeed(
          "test -L /nix/var/nix/profiles/system || "
          "(mkdir -p /nix/var/nix/profiles && "
          " ln -sfn $(readlink -f /run/current-system) /nix/var/nix/profiles/system)"
      )
      want = machine.succeed("readlink -f /nix/var/nix/profiles/system").strip()

      def make_esp(path, target, size="64M"):
          """(Re)create a tmpfs ESP whose grub.cfg references `target`.

          Always remounts from scratch. Reusing an existing mount would silently
          keep the earlier size, which the near-full subtest depends on.
          """
          machine.succeed(f"mkdir -p {path}")
          machine.execute(f"umount {path}")
          machine.succeed(f"mount -t tmpfs -o size={size} tmpfs {path}")
          machine.succeed(f"mkdir -p {path}/grub")
          machine.succeed(f"echo 'linux {target}/init root=/dev/vda' > {path}/grub/grub.cfg")

      def run_check():
          return machine.execute(f"{check} 2>&1")

      # --- A. Healthy: both ESPs mounted, both current -------------------------
      make_esp("/boot", want)
      make_esp("/boot-efi2", want)

      status, out = run_check()
      assert status == 0, f"healthy mirror reported a failure:\n{out}"
      assert "2 ESP(s) mounted and current" in out, f"unexpected healthy output:\n{out}"

      # The hardened unit must also pass.
      machine.succeed("systemctl start boot-mirror-check.service")

      # --- B. An ESP is not mounted -------------------------------------------
      # The failure `nofail` makes quiet.
      machine.succeed("umount /boot-efi2")

      status, out = run_check()
      assert status != 0, f"unmounted ESP was not detected:\n{out}"
      assert "/boot-efi2 is NOT a mountpoint" in out, f"wrong message:\n{out}"

      # --- C. An ESP is mounted but stale -------------------------------------
      # Booting that disk would land on an older generation.
      make_esp("/boot-efi2", "/nix/store/00000000000000000000000000000000-stale-system")

      status, out = run_check()
      assert status != 0, f"stale ESP was not detected:\n{out}"
      assert "does not reference the current system profile" in out, f"wrong message:\n{out}"

      # --- D. Profile, not /run/current-system --------------------------------
      # The comparison is against the profile, not the running system
      # (`nixos-rebuild boot` leaves the latter alone). Repoint the profile so
      # the two differ, then check both directions.
      other = machine.succeed("readlink -f /run/current-system").strip()
      staged = machine.succeed(
          "nix-store -qR /run/current-system | grep -m1 -- '-coreutils-'"
      ).strip()
      assert staged != other, "could not find a store path distinct from current-system"

      machine.succeed(f"ln -sfn {staged} /nix/var/nix/profiles/system")

      # grub.cfg pointing at the profile passes.
      make_esp("/boot", staged)
      make_esp("/boot-efi2", staged)
      status, out = run_check()
      assert status == 0, f"ESPs matching the profile were reported stale:\n{out}"

      # grub.cfg pointing at the running system fails.
      make_esp("/boot-efi2", other)
      status, out = run_check()
      assert status != 0, "comparison used /run/current-system instead of the profile"
      assert "does not reference the current system profile" in out, f"wrong message:\n{out}"

      # Restore for the last subtest.
      machine.succeed(f"ln -sfn {want} /nix/var/nix/profiles/system")

      # --- E. An ESP is nearly full -------------------------------------------
      # A bootloader install into a full ESP can be truncated.
      make_esp("/boot", want)
      make_esp("/boot-efi2", want, size="16M")
      machine.succeed("fallocate -l 15M /boot-efi2/filler")

      status, out = run_check()
      assert status != 0, f"full ESP was not detected:\n{out}"
      assert "full -- a bootloader install may be truncated" in out, f"wrong message:\n{out}"
    '';
}
