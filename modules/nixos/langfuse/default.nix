# services.langfuse: self-hosted Langfuse without containers. ClickHouse,
# Valkey and Garage (S3) run loopback-only on this host; PostgreSQL is a
# local services.postgresql database by default, or any server given by
# `database.*`. Every secret is generated on first start under
# /var/lib/langfuse-secrets (or copied there from a `*File` option), so
# nothing lands in the store. Everything, the web UI included, stays on
# loopback.
#
# The module takes over services.clickhouse and services.garage for the
# host (see shareBackends), and adds services.redis.servers.langfuse.
{
  config,
  options,
  lib,
  pkgs,
  extraPkgs,
  ...
}:
let
  cfg = config.services.langfuse;
  db = cfg.database;

  secretsDir = "/var/lib/langfuse-secrets";
  ingestDir = "/var/lib/langfuse-ingest";
  ingestGroup = "langfuse-ingest";
  user = "langfuse";
  bucket = "langfuse";

  ports = {
    clickhouseHttp = 8123;
    clickhouseNative = 9000;
    redis = 6380;
    garageS3 = 3900;
    garageRpc = 3901;
  };

  s3Endpoint = "http://127.0.0.1:${toString ports.garageS3}";

  # "http://127.0.0.1:8080/v1" -> "127.0.0.1"
  urlHost = url: builtins.head (builtins.match "[a-z]+://([^/:]+).*" url);

  # A host starting with "/" is a Unix socket directory, passed as libpq's
  # `host` parameter (Prisma and psql both read it).
  dbSocket = lib.hasPrefix "/" db.host;
  dbUrlPrefix = "postgresql://${db.user}";
  dbUrlSuffix =
    if dbSocket then
      "@localhost:${toString db.port}/${db.name}?host=${db.host}"
    else
      "@${db.host}:${toString db.port}/${db.name}";

  # Exports the systemd credentials (see secretCredentials) and builds
  # DATABASE_URL from the LANGFUSE_DB_URL_* parts, then runs its arguments.
  # A variable already set from environmentFile wins. Unlike an
  # EnvironmentFile, credentials pass backslashes, quotes and spaces through.
  withSecrets = pkgs.writeShellScript "langfuse-with-secrets" ''
    set -euo pipefail
    cred() { [ -n "''${CREDENTIALS_DIRECTORY:-}" ] && [ -r "$CREDENTIALS_DIRECTORY/$1" ]; }
    # var credential [prefix]
    from_cred() {
      if [ -z "''${!1:-}" ] && cred "$2"; then
        export "$1=''${3:-}$(< "$CREDENTIALS_DIRECTORY/$2")"
      fi
    }
    ${lib.concatStrings (
      lib.mapAttrsToList (
        var: c: "from_cred ${var} ${c.name}${lib.optionalString (c ? prefix) " ${c.prefix}"}\n"
      ) secretEnv
    )}
    if [ -z "''${DATABASE_URL:-}" ]; then
      pw=
      if cred db-password; then
        pw=$(printf %s "$(< "$CREDENTIALS_DIRECTORY/db-password")" | ${lib.getExe pkgs.jq} -sRr @uri)
      fi
      export DATABASE_URL="$LANGFUSE_DB_URL_PREFIX''${pw:+:$pw}$LANGFUSE_DB_URL_SUFFIX"
    fi
    exec "$@"
  '';

  # Environment variable -> file under secretsDir, for the secrets that can
  # come from secretFiles and so may hold any character.
  secretEnv = {
    NEXTAUTH_SECRET.name = "nextauth-secret";
    SALT.name = "salt";
    ENCRYPTION_KEY.name = "encryption-key";
    LANGFUSE_INIT_PROJECT_SECRET_KEY = {
      name = "project-secret-key";
      prefix = "sk-lf-";
    };
    LANGFUSE_INIT_USER_PASSWORD.name = "user-password";
  };

  # Everything but the API key, which langfuse-llm-connections adds at run
  # time from the secretKeyFile credential.
  llmConnectionBodies = lib.mapAttrs (
    provider: c:
    pkgs.writeText "langfuse-llm-connection-${provider}.json" (
      builtins.toJSON {
        inherit provider;
        inherit (c)
          adapter
          baseURL
          withDefaultModels
          ;
        customModels = c.models;
      }
    )
  ) cfg.llmConnections;

  # Non-secret settings shared by migrate, web and worker. Secrets come from
  # ${secretsDir}/langfuse.env (generated hex values only) and the
  # credentials in secretCredentials (see langfuse-secrets below).
  commonEnv = {
    LANGFUSE_DB_URL_PREFIX = dbUrlPrefix;
    LANGFUSE_DB_URL_SUFFIX = dbUrlSuffix;
    CLICKHOUSE_URL = "http://127.0.0.1:${toString ports.clickhouseHttp}";
    CLICKHOUSE_MIGRATION_URL = "clickhouse://127.0.0.1:${toString ports.clickhouseNative}";
    CLICKHOUSE_USER = user;
    CLICKHOUSE_CLUSTER_ENABLED = "false";
    REDIS_HOST = "127.0.0.1";
    REDIS_PORT = toString ports.redis;
    TELEMETRY_ENABLED = "false";
    NEXTAUTH_URL = cfg.url;
    AUTH_DISABLE_SIGNUP = "true";
    # The MCP endpoint only accepts NEXTAUTH_URL's host; local clients call
    # the port directly.
    LANGFUSE_MCP_ALLOWED_HOSTS = "127.0.0.1:${toString cfg.port},localhost:${toString cfg.port}";

    LANGFUSE_INIT_ORG_ID = "local";
    LANGFUSE_INIT_ORG_NAME = "Local";
    LANGFUSE_INIT_PROJECT_ID = "default";
    LANGFUSE_INIT_PROJECT_NAME = "Default";
    LANGFUSE_INIT_PROJECT_PUBLIC_KEY = cfg.publicKey;
    LANGFUSE_INIT_USER_EMAIL = cfg.userEmail;
    LANGFUSE_INIT_USER_NAME = cfg.userName;
  }
  # The base-URL SSRF guard rejects loopback and private hosts unless listed.
  // lib.optionalAttrs (cfg.llmConnections != { }) {
    LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST = lib.concatStringsSep "," (
      lib.unique (lib.mapAttrsToList (_: c: urlHost c.baseURL) cfg.llmConnections)
    );
  }
  // lib.optionalAttrs (cfg.smtp.connectionUrl != null) {
    SMTP_CONNECTION_URL = cfg.smtp.connectionUrl;
  }
  // lib.optionalAttrs (cfg.smtp.fromAddress != null) {
    EMAIL_FROM_ADDRESS = cfg.smtp.fromAddress;
  }
  //
    lib.concatMapAttrs
      (
        kind: prefix:
        lib.mapAttrs' (name: value: lib.nameValuePair "LANGFUSE_S3_${kind}_UPLOAD_${name}" value) {
          BUCKET = bucket;
          REGION = "garage";
          ENDPOINT = s3Endpoint;
          FORCE_PATH_STYLE = "true";
          PREFIX = prefix;
        }
      )
      {
        EVENT = "events/";
        MEDIA = "media/";
      };

  envFiles = [
    "${secretsDir}/langfuse.env"
  ]
  ++ lib.optional (cfg.environmentFile != null) cfg.environmentFile;

  hardening = {
    User = user;
    Group = user;
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

  # For the units that talk to PostgreSQL.
  databaseCredentials = lib.optional (db.passwordFile != null) "db-password:${db.passwordFile}";

  # For migrate, web and worker: the database password and secretEnv.
  secretCredentials = {
    LoadCredential =
      databaseCredentials ++ lib.mapAttrsToList (_: c: "${c.name}:${secretsDir}/${c.name}") secretEnv;
  };

  # The database and its owner come from ensureDatabases/ensureUsers, which
  # nixpkgs runs in postgresql-setup.service (older releases ran them in
  # postgresql.service's postStart).
  postgresqlUnits = lib.optionals db.createLocally (
    [ "postgresql.service" ]
    ++ lib.optional (config.systemd.services ? postgresql-setup) "postgresql-setup.service"
  );

  backends = postgresqlUnits ++ [
    "clickhouse.service"
    "redis-langfuse.service"
    "langfuse-garage-bootstrap.service"
  ];

  garage = lib.getExe config.services.garage.package;

  # Generated on first start unless the matching secretFiles entry is set.
  # name -> openssl rand -hex length.
  generatedSecrets = {
    nextauth-secret = 32;
    salt = 32;
    encryption-key = 32;
    clickhouse-password = 24;
    redis-password = 24;
    garage-rpc-secret = 32;
    s3-key-id = 12;
    s3-secret = 32;
    project-secret-key = 24;
    user-password = 16;
  };

  secretFileTargets = {
    nextauthSecret = "nextauth-secret";
    salt = "salt";
    encryptionKey = "encryption-key";
    projectSecretKey = "project-secret-key";
    initialUserPassword = "user-password";
  };

  # secretFiles option -> target name, for the options that are set.
  suppliedSecrets = lib.filterAttrs (opt: _: cfg.secretFiles.${opt} != null) secretFileTargets;

  # The packaged config enables ~20 system log tables that keep an idle server
  # busy. Langfuse reads none; query_log, part_log, error_log and crash_log
  # stay, per its scaling guide. Existing tables stay until dropped by hand.
  unusedSystemLogs = [
    "asynchronous_insert_log"
    "asynchronous_metric_log"
    "background_schedule_pool_log"
    "instrumentation_trace_log"
    "latency_log"
    "metric_log"
    "opentelemetry_span_log"
    "processors_profile_log"
    "query_metric_log"
    "query_thread_log"
    "query_views_log"
    "text_log"
    "trace_log"
  ];

  # Files that define the options this module sets on the shared ClickHouse
  # and Garage services, other than this module (its directory, or
  # default.nix when imported by file) and the module declaring the option.
  foreignDefinitions =
    service: names:
    lib.unique (
      lib.concatMap (
        name:
        let
          opt = options.services.${service}.${name} or { };
          known = [
            (toString ./.)
            (toString ./default.nix)
          ]
          ++ map toString (opt.declarations or [ ]);
        in
        lib.filter (file: !(lib.elem file known)) (map (d: d.file) (opt.definitionsWithLocations or [ ]))
      ) names
    );
  sharedBackends = lib.filterAttrs (_: files: files != [ ]) {
    clickhouse = foreignDefinitions "clickhouse" [
      "enable"
      "serverConfig"
      "usersConfig"
      "extraServerConfig"
      "extraUsersConfig"
    ];
    garage = foreignDefinitions "garage" [
      "enable"
      "settings"
      "environmentFile"
      "extraEnvironment"
    ];
  };

  secretFileOption =
    what:
    lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        File holding ${what}, read at run time by root. Null generates one on
        first start and keeps it under ${secretsDir}. A missing, unreadable
        or empty file fails `langfuse-secrets.service`, and with it Langfuse,
        rather than falling back to a generated value.
      '';
    };
in
{
  options.services.langfuse = {
    enable = lib.mkEnableOption "self-hosted Langfuse with native backing services";

    package = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.langfuse;
      defaultText = lib.literalExpression "pkgs.langfuse";
      description = "The Langfuse package to run.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Loopback port of the web UI and public API (OTLP at /api/public/otel).";
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
      defaultText = lib.literalExpression ''"http://localhost:''${toString config.services.langfuse.port}"'';
      description = "URL the browser reaches the web UI at (NEXTAUTH_URL).";
    };

    database = {
      createLocally = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable services.postgresql on this host and create the database
          and its owner, reached over the Unix socket with peer
          authentication. Requires `database.name` and `database.user` to
          be `langfuse`, the service user.
        '';
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "/run/postgresql";
        example = "db.example.org";
        description = ''
          PostgreSQL host name, or a Unix socket directory when it starts
          with `/`.
        '';
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5432;
        description = "PostgreSQL port (also selects the socket file for a socket `host`).";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = user;
        description = "PostgreSQL database name.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = user;
        description = "PostgreSQL role Langfuse connects as.";
      };

      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        example = "/run/keys/langfuse-db-password";
        description = ''
          File holding the PostgreSQL password, passed to the services as a
          systemd credential. Null connects without a password (peer or
          trust authentication). A `DATABASE_URL` in
          {option}`services.langfuse.environmentFile` replaces the URL built
          from these options.
        '';
      };
    };

    secretFiles = {
      nextauthSecret = secretFileOption "NEXTAUTH_SECRET";
      salt = secretFileOption "the API key hashing SALT";
      encryptionKey = secretFileOption "ENCRYPTION_KEY (64 hex characters)";
      projectSecretKey = secretFileOption "the initial project's secret key, without the `sk-lf-` prefix";
      initialUserPassword = secretFileOption "the initial user's password";
    };

    userEmail = lib.mkOption {
      type = lib.types.str;
      # Must pass zod email validation, so it needs a dotted domain.
      default = "admin@langfuse.local";
      description = "Login of the initial (and only) user, created on first start.";
    };

    userName = lib.mkOption {
      type = lib.types.str;
      default = "Admin";
      description = "Display name of the initial user.";
    };

    publicKey = lib.mkOption {
      type = lib.types.str;
      default = "pk-lf-local";
      description = "Public API key of the initial project; the secret key is generated.";
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Extra environment file for web, worker and migrations; overrides generated values.";
    };

    smtp = {
      connectionUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "smtp://127.0.0.1:25";
        description = ''
          SMTP_CONNECTION_URL for outgoing mail (invitations, password
          reset, email login). Null keeps mail sending unconfigured. Put a
          URL carrying credentials in
          {option}`services.langfuse.environmentFile` instead.
        '';
      };

      fromAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "langfuse@example.org";
        description = "EMAIL_FROM_ADDRESS for outgoing mail; pair with smtp.connectionUrl.";
      };
    };

    ingestUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users allowed to read the OTLP ingest credentials of the initial project:
        `{"Authorization": "Basic ..."}` as JSON from {option}`services.langfuse.ingestHeadersFile`,
        and the bare key pair from {option}`services.langfuse.ingestKeyFiles`.
      '';
    };

    ingestHeadersFile = lib.mkOption {
      type = lib.types.path;
      default = "${ingestDir}/otlp-headers.json";
      readOnly = true;
      description = "OTLP ingest headers file, readable by {option}`services.langfuse.ingestUsers`.";
    };

    ingestKeyFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = {
        public = "${ingestDir}/public-key";
        secret = "${ingestDir}/secret-key";
      };
      readOnly = true;
      description = "Key files (`public`, `secret`) readable by {option}`services.langfuse.ingestUsers`.";
    };

    ingestEnvFile = lib.mkOption {
      type = lib.types.path;
      default = "${secretsDir}/ingest.env";
      readOnly = true;
      description = ''
        Root-only `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY`/`LANGFUSE_HOST` for a
        systemd `EnvironmentFile=` of a service that sends to the initial project.
      '';
    };

    llmConnections = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            adapter = lib.mkOption {
              type = lib.types.str;
              default = "openai";
              description = "LLM adapter (`openai` covers any OpenAI-compatible server).";
            };
            baseURL = lib.mkOption {
              type = lib.types.str;
              example = "http://127.0.0.1:8080/v1";
              description = "API base URL; its host is added to the base-URL whitelist.";
            };
            models = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Custom model names offered in the playground and evals.";
            };
            withDefaultModels = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Also offer the adapter's built-in model list.";
            };
            secretKeyFile = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              default = null;
              example = "/run/keys/openai-api-key";
              description = ''
                File holding the API key sent to the server, passed to the
                upsert unit as a systemd credential. Null sends `none`, for
                keyless local servers (the API requires a non-empty value).
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        LLM connections of the initial project, keyed by provider name and
        upserted through the public API after every start of the web service.
      '';
    };

    shareBackends = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow other modules to configure services.clickhouse and
        services.garage as well. Langfuse treats both as its own: ClickHouse
        runs in UTC, capped at {option}`services.langfuse.clickhouseMaxMemory`,
        with most system log tables removed, and Langfuse's tables (and
        golang-migrate's `schema_migrations`) in the `default` database;
        Garage is a single loopback-only node on ports 3900/3901 with
        `replication_factor = 1`, Langfuse's generated RPC secret and a
        layout assigned on first start. Another user of either service
        silently gets all of this, so by default evaluation fails when a
        module outside this one sets their options. Set this after checking
        that the other user (Plausible, for example, enables ClickHouse) can
        live with it.
      '';
    };

    clickhouseMaxMemory = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4 * 1024 * 1024 * 1024;
      description = "ClickHouse `max_server_memory_usage` in bytes.";
    };

    retentionDays = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 90;
      description = ''
        Delete traces, observations, scores and media older than this many
        days, via the worker's batch retention cleaner. Applied to every
        project. Null keeps everything.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = db.createLocally -> (db.name == user && db.user == user);
        message = ''
          services.langfuse.database.createLocally needs database.name and
          database.user to be "${user}" (peer authentication as the service
          user, and ensureDBOwnership).
        '';
      }
      {
        assertion = cfg.shareBackends || sharedBackends == { };
        message = ''
          services.langfuse configures ${
            lib.concatMapStringsSep " and " (s: "services.${s}") (lib.attrNames sharedBackends)
          } for itself, but
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              s: files: "services.${s} is also set in ${lib.concatStringsSep ", " files}"
            ) sharedBackends
          )}
          Its settings would apply to the other user without notice; see
          services.langfuse.shareBackends.
        '';
      }
      {
        assertion = db.createLocally -> dbSocket;
        message = "services.langfuse.database.createLocally needs database.host to be a socket directory.";
      }
    ];

    users = {
      users.${user} = {
        isSystemUser = true;
        group = user;
      };

      groups.${user} = { };
      groups.${ingestGroup}.members = cfg.ingestUsers;
    };

    services = {
      postgresql = lib.mkIf db.createLocally {
        enable = true;
        ensureDatabases = [ db.name ];
        ensureUsers = [
          {
            name = db.user;
            ensureDBOwnership = true;
          }
        ];
      };

      clickhouse = {
        enable = true;
        # The packaged config.xml already listens on loopback only.
        serverConfig = {
          max_server_memory_usage = cfg.clickhouseMaxMemory;
          # Langfuse requires ClickHouse in UTC, whatever the host zone.
          timezone = "UTC";
          # Default 1 s; Langfuse only reads these in its seeder doctor script.
          asynchronous_metrics_update_period_s = 60;
        };
        extraServerConfig = ''
          <clickhouse>
            ${lib.concatMapStrings (t: "<${t} remove=\"1\"/>") unusedSystemLogs}
          </clickhouse>
        '';
        usersConfig.users.${user} = {
          password."@from_env" = "LANGFUSE_CLICKHOUSE_PASSWORD";
          networks.ip = [
            "::1"
            "127.0.0.1"
          ];
          profile = "default";
          quota = "default";
          access_management = 1;
        };
      };

      redis = {
        package = lib.mkDefault pkgs.valkey;
        servers.langfuse = {
          enable = true;
          bind = "127.0.0.1";
          port = ports.redis;
          requirePassFile = "${secretsDir}/redis-password";
          # BullMQ queues must never be evicted.
          settings.maxmemory-policy = "noeviction";
        };
      };

      garage = {
        enable = true;
        package = lib.mkDefault pkgs.garage;
        environmentFile = "${secretsDir}/garage.env";
        settings = {
          replication_factor = 1;
          db_engine = "sqlite";
          rpc_bind_addr = "127.0.0.1:${toString ports.garageRpc}";
          rpc_public_addr = "127.0.0.1:${toString ports.garageRpc}";
          s3_api = {
            api_bind_addr = "127.0.0.1:${toString ports.garageS3}";
            s3_region = "garage";
          };
        };
      };
    };

    systemd.services = {
      # Generates every secret once (later starts keep the existing files)
      # and copies the ones given as secretFiles on every start.
      langfuse-secrets = {
        description = "Generate Langfuse secrets";
        wantedBy = [ "multi-user.target" ];
        before = backends ++ [ "garage.service" ];
        path = [ pkgs.openssl ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "langfuse-secrets";
          StateDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          cd ${secretsDir}
          # A configured file that is missing, unreadable or empty fails the
          # unit and keeps the previous copy: generating a fresh value
          # instead would, for encryption-key, leave stored data undecryptable.
          copy() {
            local v
            if ! v=$(cat -- "$1"); then
              echo "langfuse-secrets: cannot read $1" >&2
              exit 1
            fi
            if [ -z "$v" ]; then
              echo "langfuse-secrets: $1 is empty" >&2
              exit 1
            fi
            # Trailing newlines are dropped; one inside the value would split
            # the ingest.env and Basic auth consumers of the project key.
            case $v in
              *$'\n'* | *$'\r'*)
                echo "langfuse-secrets: $1 holds more than one line" >&2
                exit 1
                ;;
            esac
            printf %s "$v" > "$2.tmp"
            mv -f "$2.tmp" "$2"
          }
          ${lib.concatStrings (
            lib.mapAttrsToList (
              opt: name: "copy ${lib.escapeShellArg cfg.secretFiles.${opt}} ${name}\n"
            ) suppliedSecrets
          )}
          gen() {
            [ -s "$1" ] && return
            openssl rand -hex "$2" > "$1.tmp"
            mv -f "$1.tmp" "$1"
          }
          ${lib.concatStrings (
            lib.mapAttrsToList (name: len: "gen ${name} ${toString len}\n") (
              removeAttrs generatedSecrets (lib.attrValues suppliedSecrets)
            )
          )}
          s3_id="GK$(cat s3-key-id)"
          # Only generated hex values; the secrets that secretFiles may supply
          # reach the services as credentials (secretEnv).
          cat > langfuse.env <<EOF
          CLICKHOUSE_PASSWORD=$(cat clickhouse-password)
          REDIS_AUTH=$(cat redis-password)
          LANGFUSE_S3_EVENT_UPLOAD_ACCESS_KEY_ID=$s3_id
          LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY=$(cat s3-secret)
          LANGFUSE_S3_MEDIA_UPLOAD_ACCESS_KEY_ID=$s3_id
          LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY=$(cat s3-secret)
          EOF
          echo "LANGFUSE_CLICKHOUSE_PASSWORD=$(cat clickhouse-password)" > clickhouse.env
          echo "GARAGE_RPC_SECRET=$(cat garage-rpc-secret)" > garage.env
          # Double-quoted with \ " ` $ escaped, which systemd's EnvironmentFile
          # parser and a POSIX shell both read back verbatim.
          envq() {
            local v=$2
            v=''${v//\\/\\\\}
            v=''${v//\"/\\\"}
            v=''${v//\`/\\\`}
            v=''${v//\$/\\\$}
            printf '%s="%s"\n' "$1" "$v"
          }
          {
            envq LANGFUSE_PUBLIC_KEY ${lib.escapeShellArg cfg.publicKey}
            envq LANGFUSE_SECRET_KEY "sk-lf-$(cat project-secret-key)"
            envq LANGFUSE_HOST http://127.0.0.1:${toString cfg.port}
          } > ${cfg.ingestEnvFile}

          install -d -m 0750 -g ${ingestGroup} ${ingestDir}
          auth=$(printf '%s' ${lib.escapeShellArg cfg.publicKey}":sk-lf-$(cat project-secret-key)" | base64 -w0)
          printf '{"Authorization": "Basic %s"}\n' "$auth" > ${cfg.ingestHeadersFile}
          printf %s ${lib.escapeShellArg cfg.publicKey} > ${cfg.ingestKeyFiles.public}
          printf %s "sk-lf-$(cat project-secret-key)" > ${cfg.ingestKeyFiles.secret}
          chgrp ${ingestGroup} ${ingestDir}/*
          chmod 0640 ${ingestDir}/*
        '';
      };

      clickhouse = {
        requires = [ "langfuse-secrets.service" ];
        after = [ "langfuse-secrets.service" ];
        serviceConfig.EnvironmentFile = "${secretsDir}/clickhouse.env";
      };

      redis-langfuse = {
        requires = [ "langfuse-secrets.service" ];
        after = [ "langfuse-secrets.service" ];
      };

      garage = {
        requires = [ "langfuse-secrets.service" ];
        after = [ "langfuse-secrets.service" ];
      };

      # One-node layout, the generated access key and the bucket; idempotent.
      langfuse-garage-bootstrap = {
        description = "Bootstrap the Garage layout, key and bucket for Langfuse";
        requires = [ "garage.service" ];
        after = [ "garage.service" ];
        environment.GARAGE_CONFIG_FILE = "/etc/garage.toml";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = "${secretsDir}/garage.env";
        };
        script = ''
          for _ in $(seq 60); do ${garage} status >/dev/null 2>&1 && break; sleep 1; done

          node=$(${garage} node id -q | cut -d@ -f1)
          if ${garage} layout show | grep -q 'No nodes currently have a role'; then
            ${garage} layout assign -z local -c 100G "$node"
            version=$(${garage} layout show | sed -n 's/.*Current cluster layout version: \([0-9]*\).*/\1/p')
            ${garage} layout apply --version $((version + 1))
          fi

          key_id="GK$(cat ${secretsDir}/s3-key-id)"
          if ! ${garage} key info "$key_id" >/dev/null 2>&1; then
            ${garage} key import --yes -n ${user} "$key_id" "$(cat ${secretsDir}/s3-secret)"
          fi
          ${garage} bucket info ${bucket} >/dev/null 2>&1 || ${garage} bucket create ${bucket}
          ${garage} bucket allow --read --write --owner ${bucket} --key "$key_id"
        '';
      };

      langfuse-migrate = {
        description = "Langfuse Postgres and ClickHouse migrations";
        requires = backends;
        after = backends ++ lib.optional (!db.createLocally) "network-online.target";
        wants = lib.optional (!db.createLocally) "network-online.target";
        environment = commonEnv;
        serviceConfig =
          hardening
          // secretCredentials
          // {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = envFiles;
            ExecStart = "${withSecrets} ${lib.getExe' cfg.package "langfuse-migrate"}";
          };
      };

      langfuse-web = {
        description = "Langfuse web UI and API";
        wantedBy = [ "multi-user.target" ];
        requires = [ "langfuse-migrate.service" ];
        after = [ "langfuse-migrate.service" ];
        environment = commonEnv // {
          HOSTNAME = "127.0.0.1";
          PORT = toString cfg.port;
        };
        serviceConfig =
          hardening
          // secretCredentials
          // {
            EnvironmentFile = envFiles;
            ExecStart = "${withSecrets} ${lib.getExe' cfg.package "langfuse-web"}";
            Restart = "on-failure";
            # Next.js drains for 110 s on SIGTERM regardless; nothing here needs it.
            TimeoutStopSec = 10;
          };
      };

      langfuse-worker = {
        description = "Langfuse background worker";
        wantedBy = [ "multi-user.target" ];
        requires = [ "langfuse-migrate.service" ];
        after = [ "langfuse-migrate.service" ];
        environment =
          commonEnv
          // {
            HOSTNAME = "127.0.0.1";
            PORT = "3030";
          }
          // lib.optionalAttrs (cfg.retentionDays != null) {
            LANGFUSE_BATCH_DATA_RETENTION_CLEANER_ENABLED = "true";
          };
        serviceConfig =
          hardening
          // secretCredentials
          // {
            EnvironmentFile = envFiles;
            ExecStart = "${withSecrets} ${lib.getExe' cfg.package "langfuse-worker"}";
            Restart = "on-failure";
            TimeoutStopSec = 10;
          };
      };

      # PUT upserts by provider, so re-running is idempotent. Connections
      # removed from the option stay in the project until deleted in the UI.
      langfuse-llm-connections = lib.mkIf (cfg.llmConnections != { }) {
        description = "Upsert the Langfuse LLM connections";
        # Pulled in by web, not multi-user.target, so its health wait stays
        # off the boot critical path.
        wantedBy = [ "langfuse-web.service" ];
        requires = [ "langfuse-web.service" ];
        after = [ "langfuse-web.service" ];
        partOf = [ "langfuse-web.service" ];
        restartTriggers = lib.attrValues llmConnectionBodies;
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          SupplementaryGroups = [ ingestGroup ];
          LoadCredential = lib.mapAttrsToList (provider: c: "llm-${provider}:${c.secretKeyFile}") (
            lib.filterAttrs (_: c: c.secretKeyFile != null) cfg.llmConnections
          );
        };
        script = ''
          api=http://127.0.0.1:${toString cfg.port}/api/public
          for _ in $(seq 120); do curl -sf "$api/health" >/dev/null && break; sleep 2; done
          auth="$(cat ${cfg.ingestKeyFiles.public}):$(cat ${cfg.ingestKeyFiles.secret})"
          # body [credential]: the request body, built here so the key never
          # reaches the store.
          upsert() {
            local key=none
            if [ -n "''${2:-}" ]; then
              key=$(< "$CREDENTIALS_DIRECTORY/$2")
            fi
            jq -c --arg key "$key" '. + {secretKey: $key}' "$1" |
              curl -sSf -X PUT -u "$auth" -H 'Content-Type: application/json' \
                --data @- "$api/llm-connections" >/dev/null
          }
          ${lib.concatStrings (
            lib.mapAttrsToList (
              provider: c:
              "upsert ${llmConnectionBodies.${provider}}${
                lib.optionalString (c.secretKeyFile != null) " ${lib.escapeShellArg "llm-${provider}"}"
              }\n"
            ) cfg.llmConnections
          )}
        '';
      };

      # The cleaner reads projects.retention_days. The UI setting is an EE
      # entitlement, so set it here, once web has created the initial project.
      langfuse-retention = lib.mkIf (cfg.retentionDays != null) {
        description = "Apply the Langfuse data retention period";
        wantedBy = [ "multi-user.target" ];
        requires = [ "langfuse-web.service" ];
        after = [ "langfuse-web.service" ];
        path = [ config.services.postgresql.package ];
        environment = { inherit (commonEnv) LANGFUSE_DB_URL_PREFIX LANGFUSE_DB_URL_SUFFIX; };
        serviceConfig =
          hardening
          // lib.optionalAttrs (databaseCredentials != [ ]) { LoadCredential = databaseCredentials; }
          // {
            Type = "oneshot";
            RemainAfterExit = true;
            EnvironmentFile = envFiles;
            ExecStart = "${withSecrets} ${pkgs.writeShellScript "langfuse-retention" ''
              set -euo pipefail
              q() { psql "$DATABASE_URL" -tAc "$1"; }
              for _ in $(seq 120); do
                [ "$(q 'SELECT count(*) FROM projects')" -gt 0 ] && break
                sleep 5
              done
              q "UPDATE projects SET retention_days = ${toString cfg.retentionDays}
                 WHERE retention_days IS DISTINCT FROM ${toString cfg.retentionDays}"
            ''}";
          };
      };
    };
  };
}
