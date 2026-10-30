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
    failedAssertions
    runCases
    ;

  base = {
    enable = true;
    embedder = {
      model = "text-embedding-3-small";
      baseUrl = "http://127.0.0.1:8080/v1";
      apiKeyFile = "/run/keys/embedder";
      dims = 1536;
    };
    llm.model = "gpt-5-mini";
  };
  eval =
    extra:
    evalNixos [
      module
      { services.mem0 = lib.recursiveUpdate base extra; }
    ];

  off = evalNixos [ module ];
  on = eval { };
  remote = eval {
    database = {
      createLocally = false;
      host = "db.example.org";
      passwordFile = "/run/keys/pg";
    };
    auth = {
      jwtSecretFile = "/run/keys/jwt";
      adminApiKeyFile = "/run/keys/admin";
    };
  };
  altPortCfg = evalNixos [
    module
    {
      services.mem0 = lib.recursiveUpdate base { };
      services.postgresql.settings.port = 5433;
    }
  ];
  remoteNoPassword = eval { database.createLocally = false; };
  clients = eval { clientUsers = [ "alice" ]; };
  badBaseUrl = eval {
    llm = {
      provider = "anthropic";
      baseUrl = "http://127.0.0.1:4000/v1";
    };
  };

  svc = config: config.systemd.services.mem0;
  creds = config: (svc config).serviceConfig.LoadCredential;
  hasAssertion = config: text: lib.any (lib.hasInfix text) (failedAssertions config);
in
runCases "nixos-mem0" {
  off-by-default = allOf [
    (expect (!(off.systemd.services ? mem0)) "unit defined without enable")
    (expect (!off.services.postgresql.enable) "postgresql enabled without mem0")
  ];

  enables-unit = allOf [
    (noFailedAssertions on)
    (expect (on.systemd.services ? mem0) "mem0 unit missing")
    (expect ((svc on).environment.MEM0_PORT == "8888") "default port not 8888")
    (expect ((svc on).environment.MEM0_HOST == "127.0.0.1") "not bound to loopback by default")
    (expect (!(lib.elem 8888 on.networking.firewall.allowedTCPPorts)) "port opened by default")
  ];

  package-default = expect (
    on.services.mem0.package.pname == "mem0-server"
  ) "package default is not mem0-server";

  local-postgresql = allOf [
    (expect on.services.postgresql.enable "postgresql not enabled")
    (expect (lib.elem "mem0" on.services.postgresql.ensureDatabases) "vector database not ensured")
    (expect (lib.elem "mem0_app" on.services.postgresql.ensureDatabases) "auth database not ensured")
    (expect (on.systemd.services ? mem0-db) "mem0-db unit missing")
    (expect (lib.elem "mem0-db.service" (svc on).requires) "mem0 does not require mem0-db")
    (expect (lib.any (
      p: p.pname or "" == "pgvector"
    ) on.services.postgresql.finalPackage.installedExtensions) "pgvector not installed")
  ];

  # Unset secrets are generated and read back as credentials, never inlined.
  generated-secrets = allOf [
    (expect (on.systemd.services ? mem0-secrets) "mem0-secrets unit missing")
    (expect (lib.elem "jwt-secret:/var/lib/mem0-secrets/jwt-secret" (creds on)) "jwt secret not loaded from the generated file")
    (expect (lib.elem "embedder-key:/run/keys/embedder" (creds on)) "embedder key not a credential")
    (expect (
      !(lib.any (lib.hasPrefix "llm-key:") (creds on))
    ) "llm key credential without llm.apiKeyFile")
  ];

  remote-database = allOf [
    (noFailedAssertions remote)
    (expect (!remote.services.postgresql.enable) "postgresql enabled with createLocally = false")
    (expect (!(remote.systemd.services ? mem0-db)) "mem0-db unit with a remote database")
    (expect (!(remote.systemd.services ? mem0-secrets)) "mem0-secrets runs with every secret given")
    (expect ((svc remote).environment.POSTGRES_HOST == "db.example.org") "database host not passed")
    (expect ((svc remote).environment.POSTGRES_PORT == "5432") "remote port does not default to 5432")
    (expect (lib.elem "postgres-password:/run/keys/pg" (creds remote)) "password file not a credential")
  ];

  # The mem0-db psql calls reach the server over the unix socket, whose name
  # carries the port, so a non-default port must be passed explicitly.
  db-setup-port = allOf [
    (expect (lib.hasInfix "-p 5432 -d postgres" on.systemd.services.mem0-db.script) "default port missing from mem0-db script")
    (expect (
      lib.length (lib.splitString "-p 5433 " altPortCfg.systemd.services.mem0-db.script) == 3
    ) "non-default postgresql port not passed to both psql calls")
    (expect (
      altPortCfg.systemd.services.mem0.environment.POSTGRES_PORT == "5433"
    ) "mem0 not pointed at the non-default port")
  ];

  remote-needs-password = expect (hasAssertion remoteNoPassword "passwordFile is required") "no assertion for a remote database without a password";

  base-url-only-openai = expect (hasAssertion badBaseUrl "llm.baseUrl only applies") "baseUrl accepted for a non-openai provider";

  client-key = allOf [
    (noFailedAssertions clients)
    (expect (clients.systemd.services ? mem0-clients) "mem0-clients unit missing")
    (expect (lib.elem "alice" clients.users.groups.mem0-clients.members) "client user not in mem0-clients")
    (expect (!(on.systemd.services ? mem0-clients)) "mem0-clients unit without clientUsers")
  ];
}
