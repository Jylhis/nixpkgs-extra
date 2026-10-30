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

  off = evalNixos [ module ];
  on = evalNixos [
    module
    { services.langfuse.enable = true; }
  ];
  remote = evalNixos [
    module
    {
      services.langfuse = {
        enable = true;
        database = {
          createLocally = false;
          host = "db.example.org";
          name = "traces";
          user = "lf";
          passwordFile = "/run/keys/langfuse-db";
        };
        secretFiles.encryptionKey = "/run/keys/langfuse-encryption-key";
      };
    }
  ];
  llm = evalNixos [
    module
    {
      services.langfuse = {
        enable = true;
        llmConnections = {
          keyed = {
            baseURL = "https://llm.example.org/v1";
            secretKeyFile = "/run/keys/llm";
          };
          keyless.baseURL = "http://127.0.0.1:8080/v1";
        };
      };
    }
  ];
  # Another module setting up ClickHouse or Garage.
  shared =
    extra:
    evalNixos [
      module
      { services.langfuse.enable = true; }
      extra
    ];
  sharedClickhouse = shared { services.clickhouse.serverConfig.http_port = 8124; };
  sharedGarage = shared { services.garage.settings.metadata_fsync = true; };
  sharedAllowed = shared {
    services.langfuse.shareBackends = true;
    services.garage.enable = true;
  };
  localOtherUser = evalNixos [
    module
    {
      services.langfuse = {
        enable = true;
        database.user = "someone";
      };
    }
  ];

  units = cfg: cfg.systemd.services;
  # DATABASE_URL without the password, as the ExecStart wrapper builds it.
  dbUrlOf =
    cfg: unit:
    let
      env = envOf cfg unit;
    in
    env.LANGFUSE_DB_URL_PREFIX + env.LANGFUSE_DB_URL_SUFFIX;
  envOf = cfg: unit: (units cfg).${unit}.environment;
in
runCases "nixos-langfuse" {
  off-by-default = allOf [
    (expect (!(units off ? langfuse-web)) "langfuse-web defined without enable")
    (expect (!off.services.postgresql.enable) "postgresql enabled without langfuse")
  ];

  enables-units = allOf [
    (noFailedAssertions on)
    (expect (lib.all (u: units on ? ${u}) [
      "langfuse-secrets"
      "langfuse-garage-bootstrap"
      "langfuse-migrate"
      "langfuse-web"
      "langfuse-worker"
    ]) "a langfuse unit is missing")
    (expect (!(units on ? langfuse-retention)) "retention unit without retentionDays")
    (expect (!(units on ? langfuse-llm-connections)) "llm-connections unit without connections")
  ];

  package-default = expect (
    on.services.langfuse.package.pname == "langfuse"
  ) "package default is not langfuse";

  local-postgres-by-default = allOf [
    (expect on.services.postgresql.enable "postgresql not enabled")
    (expect (on.services.postgresql.ensureDatabases == [ "langfuse" ]) "database not ensured")
    (expect (lib.elem "postgresql.service" (units on).langfuse-migrate.after) "migrate not after postgresql")
    # ensureDatabases/ensureUsers run there, not in postgresql.service.
    (expect (lib.all (l: lib.elem "postgresql-setup.service" l) [
      (units on).langfuse-migrate.requires
      (units on).langfuse-migrate.after
    ]) "migrate not ordered after postgresql-setup")
    (expect (
      dbUrlOf on "langfuse-web" == "postgresql://langfuse@localhost:5432/langfuse?host=/run/postgresql"
    ) "socket URL not built")
  ];

  remote-postgres = allOf [
    (noFailedAssertions remote)
    (expect (!remote.services.postgresql.enable) "postgresql enabled with createLocally = false")
    (expect (
      !(lib.elem "postgresql.service" (units remote).langfuse-migrate.after)
    ) "migrate still after postgresql")
    (expect (
      !(lib.elem "postgresql-setup.service" (units remote).langfuse-migrate.requires)
    ) "migrate still requires postgresql-setup")
    (expect (
      dbUrlOf remote "langfuse-web" == "postgresql://lf@db.example.org:5432/traces"
    ) "TCP URL not built")
    (expect (lib.elem "db-password:/run/keys/langfuse-db" ((units remote).langfuse-web.serviceConfig.LoadCredential)) "password not loaded as a credential")
    (expect (lib.hasInfix "/run/keys/langfuse-encryption-key" (units remote).langfuse-secrets.script) "secretFiles not copied")
  ];

  # A supplied secret is copied through the checked step and never
  # generated, so an unreadable file can't be replaced by a random value.
  supplied-secret-not-generated =
    let
      script = (units remote).langfuse-secrets.script;
    in
    allOf [
      (expect (lib.hasInfix "copy /run/keys/langfuse-encryption-key encryption-key" script) "encryption key not copied through the checked step")
      (expect (!(lib.hasInfix "gen encryption-key" script)) "supplied encryption key still generated")
      (expect (lib.hasInfix "gen salt" script) "salt no longer generated")
      (expect (!(lib.hasInfix "copy " (units on).langfuse-secrets.script)) "copy without secretFiles")
    ];

  # The API key is read from secretKeyFile at run time; the request bodies
  # in the store carry everything else.
  llm-key-not-in-store =
    let
      unit = (units llm).langfuse-llm-connections;
    in
    allOf [
      (noFailedAssertions llm)
      (expect (
        unit.serviceConfig.LoadCredential == [ "llm-keyed:/run/keys/llm" ]
      ) "secretKeyFile not loaded as a credential")
      (expect (lib.length unit.restartTriggers == 2) "not one body per connection")
      (expect (lib.all (
        body: !(lib.hasInfix "secretKey" body.text)
      ) unit.restartTriggers) "a request body in the store has a secretKey")
      (expect (lib.hasInfix " llm-keyed\n" unit.script) "keyed connection not sent with its credential")
      (expect (lib.hasInfix "LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST" (lib.concatStrings (lib.attrNames (envOf llm "langfuse-web")))) "base URL hosts not whitelisted")
    ];

  # The module's ClickHouse and Garage settings would silently reach any
  # other user of those services, so that needs an explicit opt-in.
  shared-backends = allOf [
    (expect (lib.any (lib.hasInfix "services.clickhouse is also set") (testLib.failedAssertions sharedClickhouse)) "another ClickHouse user did not assert")
    (expect (lib.any (lib.hasInfix "services.garage is also set") (testLib.failedAssertions sharedGarage)) "another Garage user did not assert")
    (expect (
      !(lib.any (lib.hasInfix "services.clickhouse") (testLib.failedAssertions sharedGarage))
    ) "ClickHouse flagged without another user")
    (noFailedAssertions sharedAllowed)
  ];

  local-needs-service-user = expect (lib.any (lib.hasInfix "createLocally needs database.name") (testLib.failedAssertions localOtherUser)) "createLocally with another user did not assert";

  # The secrets secretFiles may supply reach migrate, web and worker as
  # credentials exported by the start wrapper, not through langfuse.env,
  # whose parser would mangle backslashes and split on newlines.
  supplied-secrets-as-credentials =
    let
      script = (units on).langfuse-secrets.script;
    in
    allOf (
      lib.concatMap
        (unit: [
          (expect (lib.all (c: lib.elem c (units on).${unit}.serviceConfig.LoadCredential) [
            "nextauth-secret:/var/lib/langfuse-secrets/nextauth-secret"
            "salt:/var/lib/langfuse-secrets/salt"
            "encryption-key:/var/lib/langfuse-secrets/encryption-key"
            "project-secret-key:/var/lib/langfuse-secrets/project-secret-key"
            "user-password:/var/lib/langfuse-secrets/user-password"
          ]) "${unit}: a secret is not loaded as a credential")
          (expect (lib.hasInfix "langfuse-with-secrets"
            (units on).${unit}.serviceConfig.ExecStart
          ) "${unit}: not started through the wrapper")
        ])
        [
          "langfuse-migrate"
          "langfuse-web"
          "langfuse-worker"
        ]
      ++
        map (var: expect (!(lib.hasInfix "${var}=" script)) "${var} still written to an EnvironmentFile")
          [
            "NEXTAUTH_SECRET"
            "SALT"
            "ENCRYPTION_KEY"
            "LANGFUSE_INIT_PROJECT_SECRET_KEY"
            "LANGFUSE_INIT_USER_PASSWORD"
          ]
    );

  # Secrets reach the services through EnvironmentFile, never the store.
  no-secrets-in-environment = expect (
    !(lib.any (k: lib.hasInfix "SECRET" k || lib.hasInfix "PASSWORD" k || k == "SALT") (
      lib.attrNames (envOf on "langfuse-web")
    ))
  ) "a secret is set in the unit environment";

  loopback-only = allOf [
    (expect ((envOf on "langfuse-web").HOSTNAME == "127.0.0.1") "web not on loopback")
    (expect (on.services.redis.servers.langfuse.bind == "127.0.0.1") "valkey not on loopback")
    (expect (lib.hasPrefix "127.0.0.1:" on.services.garage.settings.s3_api.api_bind_addr) "garage S3 not on loopback")
    (expect (lib.hasPrefix "127.0.0.1:" on.services.garage.settings.rpc_bind_addr) "garage RPC not on loopback")
    (expect (!(lib.elem 3000 on.networking.firewall.allowedTCPPorts)) "web port opened")
  ];
}
