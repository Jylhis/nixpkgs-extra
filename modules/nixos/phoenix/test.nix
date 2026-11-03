{
  lib,
  extraPkgs,
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
    runCasesOn
    ;

  off = evalNixos [ module ];
  on = evalNixos [
    module
    {
      services.phoenix = {
        enable = true;
        ingestUsers = [ "alice" ];
      };
    }
  ];
  retained = evalNixos [
    module
    {
      services.phoenix = {
        enable = true;
        retentionDays = 30;
      };
    }
  ];
  kept = evalNixos [
    module
    {
      services.phoenix = {
        enable = true;
        retentionDays = 30;
        keepProjects = [
          "claude-ai"
          "it's"
        ];
      };
    }
  ];
  exposed = evalNixos [
    module
    {
      services.phoenix = {
        enable = true;
        host = "0.0.0.0";
      };
    }
  ];

  withHost =
    host:
    evalNixos [
      module
      {
        services.phoenix = {
          enable = true;
          inherit host;
          retentionDays = 30;
        };
      }
    ];
  # What phoenix-ingest and the retention patch (phoenix unit) talk to.
  ingestScript = c: c.systemd.services.phoenix-ingest.script;
  apiIs =
    host: url:
    let
      c = withHost host;
    in
    expect (
      lib.hasInfix "PHOENIX_ENDPOINT=${url}\n" (ingestScript c)
      && lib.hasInfix "${url}/healthz" (ingestScript c)
    ) "host ${host} should be reached at ${url}";

  unit = c: c.systemd.services.phoenix;
in
runCasesOn extraPkgs.arize-phoenix.meta.platforms "nixos-phoenix" {
  off-by-default = expect (
    !(off.systemd.services ? phoenix) && !(off.users.users ? phoenix)
  ) "units or user defined without enable";
  enables-units = allOf [
    (noFailedAssertions on)
    (expect (
      on.systemd.services ? phoenix
      && on.systemd.services ? phoenix-secrets
      && on.systemd.services ? phoenix-ingest
    ) "a phoenix unit is missing")
  ];
  package-default = expect (lib.hasPrefix "arize-phoenix" on.services.phoenix.package.pname) "package default does not resolve to arize-phoenix";
  auth-on = expect ((unit on).environment.PHOENIX_ENABLE_AUTH == "true") "authentication not enabled";
  no-telemetry = allOf [
    (expect ((unit on).environment.PHOENIX_TELEMETRY_ENABLED == "false") "telemetry not disabled")
    (expect (
      (unit on).environment.PHOENIX_ALLOW_EXTERNAL_RESOURCES == "false"
    ) "external resources not disabled")
  ];
  secrets-not-in-environment = expect (
    !((unit on).environment ? PHOENIX_SECRET) && !((unit on).environment ? PHOENIX_ADMIN_SECRET)
  ) "a secret is in the unit environment (store)";
  loopback-only = expect (
    (unit on).serviceConfig.IPAddressDeny == "any"
  ) "loopback unit not restricted";
  exposed-host-unrestricted = expect (
    !((unit exposed).serviceConfig ? IPAddressDeny)
  ) "non-loopback host still restricted to loopback";
  retention-unset = expect (
    !((unit on).environment ? PHOENIX_DEFAULT_RETENTION_POLICY_DAYS)
  ) "retention set without retentionDays";
  retention-set = expect (
    (unit retained).environment.PHOENIX_DEFAULT_RETENTION_POLICY_DAYS == "30"
  ) "retentionDays not passed on";
  keep-unset = expect (
    !(lib.hasInfix "keep-forever" (ingestScript retained))
  ) "keep-forever policy set without keepProjects";
  keep-set = expect (
    lib.hasInfix "keep-forever" (ingestScript kept)
    && lib.hasInfix "for name in claude-ai 'it'\\''s'; do" (ingestScript kept)
    && lib.hasInfix "maxDays: 0" (ingestScript kept)
  ) "keepProjects not in the keep-forever policy";
  ingest-group = expect (
    on.users.groups.phoenix-ingest.members == [ "alice" ]
  ) "ingestUsers not in the phoenix-ingest group";
  firewall-closed = expect (
    !(lib.elem 6006 on.networking.firewall.allowedTCPPorts)
  ) "port opened by default";
  api-default = apiIs "127.0.0.1" "http://127.0.0.1:6006";
  api-ipv6-loopback = apiIs "::1" "http://[::1]:6006";
  api-wildcard-v4 = apiIs "0.0.0.0" "http://127.0.0.1:6006";
  api-wildcard-v6 = apiIs "::" "http://[::1]:6006";
  api-lan-address = apiIs "192.0.2.10" "http://192.0.2.10:6006";
  retention-uses-listen-address = expect (lib.hasInfix "http://[::1]:6006/graphql" (ingestScript (withHost "::1"))) "retention patch does not use the listen address";
}
