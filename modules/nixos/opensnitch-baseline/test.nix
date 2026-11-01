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
        connections.ssh-tailnet = {
          programs = [ "/run/current-system/sw/bin/ssh" ];
          domains = [ "example.ts.net" ];
          network = "100.64.0.0/10";
          ports = [ 22 ];
        };
        connections.block-telemetry = {
          action = "deny";
          programs = [ "/run/current-system/sw/bin/telemetry" ];
          hosts = [ "telemetry.example.com" ];
        };
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
  sshTailnet = rules.allow-ssh-tailnet.operator.list;
  operandsOf = list: map (o: o.operand) list;
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
  connection-fields = allOf [
    (expect (
      operandsOf sshTailnet == [
        "process.path"
        "dest.host"
        "dest.network"
        "dest.port"
      ]
    ) "connection rule does not AND every set field")
    (expect (
      (lib.elemAt sshTailnet 1).data == "^((.+\\.)?example\\.ts\\.net)$"
    ) "domain does not match subdomains")
  ];
  deny-connection = expect (
    rules.deny-block-telemetry.action == "deny"
  ) "deny connection not rendered as deny";
  default-connections = expect (
    rules ? allow-nix-fetch && rules ? allow-nix-fod-fetchers
  ) "nix fetch connections missing";
  nix-hosts-exposed = expect (lib.elem "cache.example.org" on.services.opensnitchBaseline.nixHosts) "nixHosts does not list the substituter host";
  cache-hosts = allOf [
    (expect (lib.hasInfix "cache\\.example\\.org" cacheHosts) "https substituter host missing")
    (expect (lib.hasInfix "objects\\.example\\.net" cacheHosts) "s3 endpoint host missing")
  ];
}
