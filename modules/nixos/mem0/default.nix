# services.mem0: the self-hosted mem0 memory REST server.
#
# Vectors live in PostgreSQL with pgvector, accounts and API keys in a second
# database. Both are provisioned on a local services.postgresql unless
# `database.createLocally = false`.
#
# Unset secrets are generated once under /var/lib/mem0-secrets. The config is
# rendered at run time from systemd credentials, so nothing secret reaches the
# Nix store.
{
  config,
  lib,
  pkgs,
  extraPkgs,
  ...
}:
let
  cfg = config.services.mem0;
  db = cfg.database;
  # The local server may listen on a non-default port; the unix socket name follows it.
  pgPort = toString config.services.postgresql.settings.port;

  secretsDir = "/var/lib/mem0-secrets";
  clientsDir = "/var/lib/mem0-clients";
  clientsGroup = "mem0-clients";
  user = "mem0";
  stateDir = "/var/lib/mem0";
  api = "http://${
    if
      lib.elem cfg.host [
        "0.0.0.0"
        "::"
      ]
    then
      "127.0.0.1"
    else
      cfg.host
  }:${toString cfg.port}";

  # Credential name -> file. A secret without a file of its own is generated
  # by mem0-secrets.
  secretFiles = {
    postgres-password = db.passwordFile;
    jwt-secret = cfg.auth.jwtSecretFile;
    admin-api-key = cfg.auth.adminApiKeyFile;
  };
  generated =
    lib.attrNames (lib.filterAttrs (_: file: file == null) secretFiles)
    ++ lib.optional (cfg.clientUsers != [ ]) "admin-password";
  secretPath =
    name:
    if secretFiles.${name} or null != null then
      toString secretFiles.${name}
    else
      "${secretsDir}/${name}";
  credential = name: "${name}:${secretPath name}";

  providerConfig =
    p:
    {
      inherit (p) model;
    }
    // lib.optionalAttrs (p.baseUrl != null) { openai_base_url = p.baseUrl; }
    // p.settings;

  baseConfig = lib.recursiveUpdate {
    version = "v1.1";
    vector_store = {
      provider = "pgvector";
      config = {
        inherit (db) host port user;
        dbname = db.name;
        collection_name = cfg.collection;
        embedding_model_dims = cfg.embedder.dims;
        # pgvector cannot index more than 2000 dimensions; searches scan.
        hnsw = false;
      };
    };
    embedder = {
      inherit (cfg.embedder) provider;
      config = providerConfig cfg.embedder // {
        embedding_dims = cfg.embedder.dims;
      };
    };
    llm = {
      inherit (cfg.llm) provider;
      config = {
        temperature = 0.2;
      }
      // providerConfig cfg.llm;
    };
    history_db_path = "${stateDir}/history.db";
  } cfg.settings;

  baseConfigFile = pkgs.writeText "mem0-config.json" (builtins.toJSON baseConfig);

  # Reads the credentials into the server's environment and the rendered
  # config, then runs the server.
  start = pkgs.writeShellScript "mem0-start" ''
    set -eu
    cred() { if [ -r "$CREDENTIALS_DIRECTORY/$1" ]; then cat "$CREDENTIALS_DIRECTORY/$1"; else echo none; fi; }
    POSTGRES_PASSWORD=$(cred postgres-password)
    JWT_SECRET=$(cred jwt-secret)
    ADMIN_API_KEY=$(cred admin-api-key)
    export POSTGRES_PASSWORD JWT_SECRET ADMIN_API_KEY
    ${lib.getExe pkgs.jq} \
      --arg pw "$POSTGRES_PASSWORD" \
      --arg ek "$(cred embedder-key)" \
      --arg lk "$(cred llm-key)" \
      '.vector_store.config.password = $pw
       | .embedder.config.api_key = $ek
       | .llm.config.api_key = $lk' ${baseConfigFile} > "$RUNTIME_DIRECTORY/config.json"
    export MEM0_CONFIG_FILE="$RUNTIME_DIRECTORY/config.json"
    exec ${lib.getExe cfg.package}
  '';

  hardening = {
    NoNewPrivileges = true;
    PrivateTmp = true;
    PrivateDevices = true;
    ProtectSystem = "strict";
    ProtectHome = true;
    ProtectKernelTunables = true;
    ProtectKernelModules = true;
    ProtectKernelLogs = true;
    ProtectControlGroups = true;
    ProtectClock = true;
    ProtectHostname = true;
    ProtectProc = "invisible";
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    LockPersonality = true;
    SystemCallArchitectures = "native";
    CapabilityBoundingSet = "";
    UMask = "0077";
  };

  secretFileOption =
    what:
    lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File holding ${what}. Unset generates one on first start under
        {file}`${secretsDir}`. The file is read as a systemd credential at run
        time, so it never enters the Nix store.
      '';
    };

  providerOptions = what: providers: {
    provider = lib.mkOption {
      type = lib.types.enum providers;
      default = "openai";
      description = ''
        ${what} provider. These are the providers the mem0 server bundles;
        `openai` also covers any OpenAI-compatible server through `baseUrl`.
      '';
    };

    model = lib.mkOption {
      type = lib.types.str;
      description = "${what} model name.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Base URL of an OpenAI-compatible ${lib.toLower what} server
        (`openai_base_url`). Only for the `openai` provider; null uses the
        OpenAI API.
      '';
      example = "http://127.0.0.1:8080/v1";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File holding the API key of the ${lib.toLower what} provider. Unset
        sends a placeholder key, for local servers that ignore it. The file is
        read as a systemd credential, so it never enters the Nix store.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Extra provider config fields, merged into the ${lib.toLower what}
        `config` of the mem0 MemoryConfig. Not for secrets: the values are
        written to the Nix store.
      '';
      example = {
        max_tokens = 2000;
      };
    };
  };
in
{
  options.services.mem0 = {
    enable = lib.mkEnableOption "the self-hosted mem0 memory server";

    package = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.mem0-server;
      defaultText = lib.literalExpression "pkgs.mem0-server";
      description = "The mem0-server package to run.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the REST server binds to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Port of the REST server.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open `port` in the host firewall.";
    };

    collection = lib.mkOption {
      type = lib.types.str;
      default = "memories";
      description = ''
        Name of the pgvector table that holds the memories. Its vector size is
        fixed when the table is created, so a new `embedder.dims` needs a new
        collection.
      '';
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Provision the databases on a local {option}`services.postgresql`
          with the pgvector extension: create both databases and the role,
          set the role's password and enable `vector`. With false, the server
          at `host` must already have both databases, owned by `user`, with
          the `vector` extension in `name`.
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1";
        description = "Host of the PostgreSQL server (password authentication over TCP).";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = if db.createLocally then config.services.postgresql.settings.port else 5432;
        defaultText = lib.literalExpression "if createLocally then config.services.postgresql.settings.port else 5432";
        description = "Port of the PostgreSQL server.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "mem0";
        description = "Database that holds the memory vectors (pgvector).";
      };

      authName = lib.mkOption {
        type = lib.types.str;
        default = "mem0_app";
        description = "Database that holds the server's accounts and API keys.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "mem0";
        description = "PostgreSQL role the server connects as.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = ''
          File holding the password of `user`. Required with
          `createLocally = false`; unset with a local server generates one on
          first start under {file}`${secretsDir}`. The server puts it in a
          connection URL, so keep it to URL-safe characters.
        '';
      };
    };

    auth = {
      jwtSecretFile = secretFileOption "the secret that signs the server's JWT sessions";
      adminApiKeyFile = secretFileOption "the bootstrap admin API key (sent as `X-API-Key`)";
    };

    llm = providerOptions "LLM" [
      "openai"
      "anthropic"
      "gemini"
    ];

    embedder =
      providerOptions "Embedding" [
        "openai"
        "gemini"
      ]
      // {
        dims = lib.mkOption {
          type = lib.types.ints.between 1 16000;
          description = "Vector size of the embedding model.";
          example = 1536;
        };
      };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        Extra mem0 MemoryConfig fields, merged recursively over the generated
        config (for example `custom_fact_extraction_prompt`). Not for
        secrets: the values are written to the Nix store.
      '';
    };

    clientUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Users allowed to read a client API key. When set, a one-shot unit
        creates the first (admin) account and one API key in
        {file}`${clientsDir}/api-key`, readable by the `${clientsGroup}`
        group these users join.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = db.createLocally || db.passwordFile != null;
        message = "services.mem0.database.passwordFile is required with database.createLocally = false.";
      }
      {
        assertion = cfg.llm.baseUrl == null || cfg.llm.provider == "openai";
        message = "services.mem0.llm.baseUrl only applies to the openai provider.";
      }
      {
        assertion = cfg.embedder.baseUrl == null || cfg.embedder.provider == "openai";
        message = "services.mem0.embedder.baseUrl only applies to the openai provider.";
      }
    ];

    users = {
      users.${user} = {
        isSystemUser = true;
        group = user;
      };
      groups = {
        ${user} = { };
      }
      // lib.optionalAttrs (cfg.clientUsers != [ ]) {
        ${clientsGroup}.members = cfg.clientUsers;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];

    services.postgresql = lib.mkIf db.createLocally {
      enable = true;
      extensions = ps: [ ps.pgvector ];
      ensureDatabases = [
        db.name
        db.authName
      ];
      ensureUsers = [ { name = db.user; } ];
    };

    systemd.services = {
      # Generates the secrets that have no file of their own, once; later
      # starts keep the existing files.
      mem0-secrets = lib.mkIf (generated != [ ]) {
        description = "Generate mem0 secrets";
        wantedBy = [ "multi-user.target" ];
        before = [
          "mem0-db.service"
          "mem0.service"
        ];
        path = [ pkgs.openssl ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "mem0-secrets";
          StateDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          cd ${secretsDir}
          for name in ${lib.escapeShellArgs generated}; do
            [ -s "$name" ] || openssl rand -hex 24 > "$name"
          done
        '';
      };

      # Sets the role password, hands both databases to the role and enables
      # pgvector, all of which need the superuser.
      mem0-db = lib.mkIf db.createLocally {
        description = "Prepare the mem0 databases";
        wantedBy = [ "multi-user.target" ];
        requires = [ "postgresql.service" ] ++ lib.optional (generated != [ ]) "mem0-secrets.service";
        after = [
          "postgresql.service"
          "postgresql-setup.service"
        ]
        ++ lib.optional (generated != [ ]) "mem0-secrets.service";
        path = [ config.services.postgresql.finalPackage ];
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "postgres";
          LoadCredential = credential "postgres-password";
          RestrictAddressFamilies = [ "AF_UNIX" ];
        };
        script = ''
          psql -h /run/postgresql -p ${pgPort} -d postgres -v ON_ERROR_STOP=1 \
            -v pw="$(cat "$CREDENTIALS_DIRECTORY/postgres-password")" \
            -v role=${lib.escapeShellArg db.user} \
            -v vecdb=${lib.escapeShellArg db.name} \
            -v authdb=${lib.escapeShellArg db.authName} <<'SQL'
          ALTER ROLE :"role" PASSWORD :'pw';
          ALTER DATABASE :"vecdb" OWNER TO :"role";
          ALTER DATABASE :"authdb" OWNER TO :"role";
          SQL
          psql -h /run/postgresql -p ${pgPort} -d ${lib.escapeShellArg db.name} -v ON_ERROR_STOP=1 \
            -c 'CREATE EXTENSION IF NOT EXISTS vector'
        '';
      };

      mem0 = {
        description = "mem0 memory server";
        wantedBy = [ "multi-user.target" ];
        requires =
          lib.optional db.createLocally "mem0-db.service"
          ++ lib.optional (generated != [ ]) "mem0-secrets.service";
        after = [
          "network.target"
        ]
        ++ lib.optional db.createLocally "mem0-db.service"
        ++ lib.optional (generated != [ ]) "mem0-secrets.service";
        restartTriggers = [ baseConfigFile ];
        environment = {
          MEM0_HOST = cfg.host;
          MEM0_PORT = toString cfg.port;
          MEM0_TELEMETRY = "false";
          POSTGRES_HOST = db.host;
          POSTGRES_PORT = toString db.port;
          POSTGRES_USER = db.user;
          APP_DB_NAME = db.authName;
          HISTORY_DB_PATH = "${stateDir}/history.db";
        };
        serviceConfig = hardening // {
          User = user;
          Group = user;
          ExecStart = start;
          LoadCredential = [
            (credential "postgres-password")
            (credential "jwt-secret")
            (credential "admin-api-key")
          ]
          ++ lib.optional (cfg.embedder.apiKeyFile != null) "embedder-key:${toString cfg.embedder.apiKeyFile}"
          ++ lib.optional (cfg.llm.apiKeyFile != null) "llm-key:${toString cfg.llm.apiKeyFile}";
          StateDirectory = "mem0";
          RuntimeDirectory = "mem0";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };

      # Creates the first (admin) account and one API key for local clients,
      # once. The key cannot be read back from the server, so an existing key
      # file is kept.
      mem0-clients = lib.mkIf (cfg.clientUsers != [ ]) {
        description = "Create the mem0 client API key";
        wantedBy = [ "mem0.service" ];
        requires = [ "mem0.service" ];
        after = [ "mem0.service" ];
        partOf = [ "mem0.service" ];
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          LoadCredential = [
            (credential "admin-api-key")
            (credential "admin-password")
          ];
          StateDirectory = "mem0-clients";
          StateDirectoryMode = "0750";
          CapabilityBoundingSet = [ "CAP_CHOWN" ];
        };
        script = ''
          for _ in $(seq 120); do
            curl -sf ${api}/auth/setup-status >/dev/null && break
            sleep 2
          done
          if [ "$(curl -sf ${api}/auth/setup-status | jq .needsSetup)" = true ]; then
            jq -n --rawfile p "$CREDENTIALS_DIRECTORY/admin-password" \
              '{name: "admin", email: "admin@mem0.example.com", password: ($p | rtrimstr("\n"))}' |
              curl -sSf -X POST -H 'Content-Type: application/json' --data @- \
                ${api}/auth/register >/dev/null
          fi
          key=${clientsDir}/api-key
          if [ ! -s "$key" ]; then
            curl -sSf -X POST -H "X-API-Key: $(cat "$CREDENTIALS_DIRECTORY/admin-api-key")" \
              -H 'Content-Type: application/json' \
              -d '{"label": "clients"}' ${api}/api-keys | jq -j .key > "$key"
          fi
          chgrp ${clientsGroup} ${clientsDir} "$key"
          chmod 0640 "$key"
        '';
      };
    };
  };
}
