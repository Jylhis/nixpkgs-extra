{
  lib,
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

  mirrored = evalNixos [
    module
    {
      boot.loader.grub.mirroredBoots = [
        {
          path = "/boot";
          devices = [ "/dev/vda" ];
        }
        {
          path = "/boot-efi2";
          devices = [ "/dev/vdb" ];
        }
      ];
    }
  ];
  plain = evalNixos [ module ];
in
runCases "nixos-boot-mirror" {
  inert-without-mirrored-boots = allOf [
    (expect (!plain.systemd.services ? boot-mirror-check) "service present without mirroredBoots")
    (expect (!plain.systemd.timers ? boot-mirror-check) "timer present without mirroredBoots")
  ];
  service-with-mirrored-boots = allOf [
    (expect (mirrored.systemd.services ? boot-mirror-check) "service missing")
    (expect (mirrored.systemd.timers ? boot-mirror-check) "timer missing")
    (expect (lib.hasInfix "boot-mirror-check" mirrored.systemd.services.boot-mirror-check.serviceConfig.ExecStart) "ExecStart not the check script")
    (noFailedAssertions mirrored)
  ];
}
