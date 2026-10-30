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

  grub = {
    boot.loader.grub = {
      enable = lib.mkForce true;
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

  off = evalNixos [
    module
    grub
  ];
  on = evalNixos [
    module
    grub
    {
      boot.fallbackBoot = {
        enable = true;
        settleSeconds = 30;
        criticalUnits = [ "sshd.service" ];
      };
    }
  ];
  noMirror = evalNixos [
    module
    { boot.fallbackBoot.enable = true; }
  ];
  failed = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
  cases = runCases "nixos-boot-fallback-eval" {
    inert-by-default = allOf [
      (expect (!off.systemd.services ? boot-fallback-mark) "service present without enable")
      (expect (
        !(lib.hasInfix "bootfb_" off.boot.loader.grub.extraConfig)
      ) "grub snippet present without enable")
    ];
    wires-grub-and-service = allOf [
      (expect (lib.hasInfix "bootfb_armed" on.boot.loader.grub.extraConfig) "grub snippet missing")
      (expect (lib.hasInfix "grubenv" on.boot.loader.grub.extraPrepareConfig) "prepare snippet missing")
      (expect (on.systemd.services ? boot-fallback-mark) "mark service missing")
      (expect (
        on.systemd.services.boot-fallback-mark.serviceConfig.ReadWritePaths == [
          "/boot"
          "/boot-efi2"
        ]
      ) "ESPs not writable for the mark service")
      (noFailedAssertions on)
    ];
    mirror-required = expect (lib.any (lib.hasInfix "mirroredBoots") (failed noMirror)) "no assertion without mirroredBoots";
  };
in
# The mark script only exists as a built file, so its content is checked in a
# build step next to the eval cases.
pkgs.runCommand "nixos-boot-fallback" { inherit cases; } ''
  script=${on.systemd.services.boot-fallback-mark.serviceConfig.ExecStart}
  # The running generation, not the profile: after a GRUB fallback the system
  # profile still points at the failed generation.
  grep -q /run/booted-system "$script"
  if grep -q 'readlink /nix/var/nix/profiles/system)' "$script"; then
    echo "last-good derived from the system profile" >&2
    exit 1
  fi
  touch $out
''
