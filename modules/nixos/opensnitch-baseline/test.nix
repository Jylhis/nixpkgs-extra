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
    {
      services.opensnitchBaseline = {
        enable = true;
        allowPrograms.example = "/run/current-system/sw/bin/example";
      };
      nix.settings.substituters = [
        "https://cache.example.org"
        "s3://bucket?endpoint=objects.example.net&region=auto"
      ];
    }
  ];
  off = evalNixos [ module ];

  rules = on.services.opensnitch.rules;
  cacheHosts = (lib.elemAt rules.allow-nix-caches.operator.list 1).data;
in
runCases "nixos-opensnitch-baseline" {
  enables-opensnitch = allOf [
    (expect on.services.opensnitch.enable "opensnitch not enabled")
    (noFailedAssertions on)
  ];
  off-by-default = expect (!off.services.opensnitch.enable) "enabled without enable = true";
  loopback-rule = expect (rules ? "000-allow-loopback") "no loopback rule";
  extra-program = expect (
    rules.allow-example.operator.data == "/run/current-system/sw/bin/example"
  ) "allowPrograms not rendered";
  cache-hosts = allOf [
    (expect (lib.hasInfix "cache\\.example\\.org" cacheHosts) "https substituter host missing")
    (expect (lib.hasInfix "objects\\.example\\.net" cacheHosts) "s3 endpoint host missing")
  ];
}
