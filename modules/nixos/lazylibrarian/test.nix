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

  on = evalNixos [
    module
    { services.lazylibrarian.enable = true; }
  ];
  off = evalNixos [ module ];
  custom = evalNixos [
    module
    {
      services.lazylibrarian = {
        enable = true;
        port = 8080;
        openFirewall = true;
        dataDir = "/srv/lazylibrarian";
        user = "media";
        group = "media";
        extraArgs = [ "--noipv6" ];
      };
      users.users.media = {
        isSystemUser = true;
        group = "media";
      };
      users.groups.media = { };
    }
  ];

  serviceOf = config: config.systemd.services.lazylibrarian.serviceConfig;
  execStart = config: (serviceOf config).ExecStart;
in
runCases "nixos-lazylibrarian" {
  off-by-default = expect (!(off.systemd.services ? lazylibrarian)) "service defined without enable";

  enables-service = allOf [
    (expect (on.systemd.services ? lazylibrarian) "no lazylibrarian service")
    (noFailedAssertions on)
  ];

  default-user = allOf [
    (expect (on.users.users.lazylibrarian.isSystemUser or false) "no lazylibrarian system user")
    (expect (on.users.groups ? lazylibrarian) "no lazylibrarian group")
    (expect ((serviceOf on).User == "lazylibrarian") "service not run as lazylibrarian")
  ];

  default-state-dir = allOf [
    (expect ((serviceOf on).StateDirectory == "lazylibrarian") "StateDirectory not set")
    (expect (lib.hasInfix "--datadir /var/lib/lazylibrarian" (execStart on)) "default datadir not passed")
    (expect (lib.hasInfix "--port 5299" (execStart on)) "default port not passed")
    (expect (lib.hasInfix "--nolaunch" (execStart on)) "--nolaunch missing")
  ];

  firewall-closed-by-default = expect (
    !(lib.elem 5299 on.networking.firewall.allowedTCPPorts)
  ) "port opened without openFirewall";

  custom-settings = allOf [
    (noFailedAssertions custom)
    (expect (lib.hasInfix "--datadir /srv/lazylibrarian" (execStart custom)) "custom datadir not passed")
    (expect (lib.hasInfix "--port 8080" (execStart custom)) "custom port not passed")
    (expect (lib.hasSuffix "--noipv6" (execStart custom)) "extraArgs not appended")
    (expect (lib.elem 8080 custom.networking.firewall.allowedTCPPorts) "openFirewall did not open port")
    (expect (!(custom.users.users ? lazylibrarian)) "default user created for a custom user")
    (expect (!(custom.users.groups ? lazylibrarian)) "default group created for a custom group")
    (expect (!((serviceOf custom) ? StateDirectory)) "StateDirectory set for a custom dataDir")
    (expect (
      custom.systemd.tmpfiles.settings.lazylibrarian."/srv/lazylibrarian".d.user == "media"
    ) "custom dataDir not created for the custom user")
  ];
}
