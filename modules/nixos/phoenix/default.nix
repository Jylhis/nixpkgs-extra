# services.phoenix: self-hosted Arize Phoenix (OpenInference tracing UI and
# OTLP collector) on SQLite. Every secret is generated on first start under
# /var/lib/phoenix-secrets, so nothing lands in the store. Authentication is
# on: the OTLP endpoint and the REST API need a system API key, which the
# phoenix-ingest unit creates once and hands to services.phoenix.ingestUsers.
{
  config,
  lib,
  pkgs,
  extraPkgs,
  ...
}:
let
  cfg = config.services.phoenix;

  secretsDir = "/var/lib/phoenix-secrets";
  ingestDir = "/var/lib/phoenix-ingest";
  ingestGroup = "phoenix-ingest";
  user = "phoenix";
  workingDir = "/var/lib/phoenix";

  # The address the helper units dial: the one Phoenix listens on, with a
  # wildcard bind mapped to loopback and an IPv6 literal bracketed.
  clientHost =
    if cfg.host == "0.0.0.0" then
      "127.0.0.1"
    else if cfg.host == "::" then
      "[::1]"
    else if lib.hasInfix ":" cfg.host && !(lib.hasPrefix "[" cfg.host) then
      "[${cfg.host}]"
    else
      cfg.host;
  api = "http://${clientHost}:${toString cfg.port}";

  loopback = lib.elem cfg.host [
    "127.0.0.1"
    "::1"
    "localhost"
  ];

  # Phoenix seeds its default retention policy (id 0) only when it is missing,
  # so PHOENIX_DEFAULT_RETENTION_POLICY_DAYS never changes an existing
  # database. This sets the policy through the GraphQL API on every start; a
  # repeat run is a no-op patch. The API keeps the cron schedule and the
  # database schema Phoenix's own business.
  setRetention = ''
    policy=$(printf 'ProjectTraceRetentionPolicy:0' | base64)
    jq -n --arg id "$policy" '{
      query: "mutation($i: PatchProjectTraceRetentionPolicyInput!) { patchProjectTraceRetentionPolicy(input: $i) { __typename } }",
      variables: {i: {id: $id, rule: {maxDays: {maxDays: ${toString cfg.retentionDays}}}}}
    }' |
      curl -sSf -X POST -H "Authorization: Bearer $PHOENIX_ADMIN_SECRET" \
        -H 'Content-Type: application/json' --data @- ${api}/graphql |
      jq -e 'has("errors") | not' >/dev/null
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
in
{
  options.services.phoenix = {
    enable = lib.mkEnableOption "self-hosted Arize Phoenix on SQLite";

    package = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.arize-phoenix;
      defaultText = lib.literalExpression "pkgs.arize-phoenix";
      description = "The Arize Phoenix package to run.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the web UI, REST API and OTLP/HTTP collector bind to.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6006;
      description = "Port of the web UI, REST API and OTLP/HTTP collector (`/v1/traces`).";
    };

    grpcPort = lib.mkOption {
      type = lib.types.port;
      default = 4317;
      description = ''
        Port of the OTLP/gRPC collector. Phoenix cannot disable it. The packaged
        server binds it to {option}`services.phoenix.host` (PHOENIX_GRPC_HOST),
        and while that is a loopback address the unit may use loopback traffic
        only (`IPAddressDeny`).
      '';
    };

    url = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:${toString cfg.port}";
      defaultText = lib.literalExpression ''"http://localhost:''${toString config.services.phoenix.port}"'';
      description = "URL the browser reaches the web UI at (PHOENIX_ROOT_URL).";
    };

    retentionDays = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 90;
      description = ''
        Retention in days of the default trace retention policy, the one every
        project without its own policy uses. Phoenix applies it weekly.
        The value seeds a new database (PHOENIX_DEFAULT_RETENTION_POLICY_DAYS), and
        `phoenix-ingest.service` patches the policy of an existing database
        on each start. Null leaves the policy alone, which keeps everything
        on a new database.
      '';
    };

    ingestUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        Users allowed to read the system API key in {option}`services.phoenix.ingestKeyFile`
        and the OTLP header file {option}`services.phoenix.ingestHeadersFile`.
        They become members of the `${ingestGroup}` group.
      '';
    };

    ingestKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "${ingestDir}/api-key";
      readOnly = true;
      description = "System API key file, readable by {option}`services.phoenix.ingestUsers`.";
    };

    ingestHeadersFile = lib.mkOption {
      type = lib.types.path;
      default = "${ingestDir}/otlp-headers.json";
      readOnly = true;
      description = ''
        OTLP ingest headers (`{"Authorization": "Bearer ..."}`), readable by
        {option}`services.phoenix.ingestUsers`.
      '';
    };

    ingestEnvFile = lib.mkOption {
      type = lib.types.path;
      default = "${secretsDir}/ingest.env";
      readOnly = true;
      description = ''
        Root-only `PHOENIX_API_KEY`/`PHOENIX_COLLECTOR_ENDPOINT`/`PHOENIX_ENDPOINT` for a
        systemd `EnvironmentFile=` of a service that sends to Phoenix.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users = {
      users.${user} = {
        isSystemUser = true;
        group = user;
      };
      groups = {
        ${user} = { };
        ${ingestGroup}.members = cfg.ingestUsers;
      };
    };

    systemd.services = {
      # Generates every secret once; later starts keep the existing files.
      phoenix-secrets = {
        description = "Generate Phoenix secrets";
        wantedBy = [ "multi-user.target" ];
        before = [
          "phoenix.service"
          "phoenix-ingest.service"
        ];
        path = [ pkgs.openssl ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "phoenix-secrets";
          StateDirectoryMode = "0700";
          UMask = "0077";
        };
        # Phoenix wants 32 or more characters with a digit and a lowercase letter,
        # and the two secrets must differ; 64 hex characters do that.
        script = ''
          cd ${secretsDir}
          gen() { [ -s "$1" ] || openssl rand -hex "$2" > "$1"; }
          gen secret 32
          gen admin-secret 32
          gen admin-password 24
          cat > phoenix.env <<EOF
          PHOENIX_SECRET=$(cat secret)
          PHOENIX_ADMIN_SECRET=$(cat admin-secret)
          PHOENIX_DEFAULT_ADMIN_INITIAL_PASSWORD=$(cat admin-password)
          EOF
        '';
      };

      phoenix = {
        description = "Arize Phoenix";
        wantedBy = [ "multi-user.target" ];
        requires = [ "phoenix-secrets.service" ];
        after = [
          "phoenix-secrets.service"
          "network.target"
        ];
        environment = {
          PHOENIX_HOST = cfg.host;
          PHOENIX_PORT = toString cfg.port;
          PHOENIX_GRPC_PORT = toString cfg.grpcPort;
          PHOENIX_GRPC_HOST = if lib.hasInfix ":" cfg.host then "[${cfg.host}]" else cfg.host;
          PHOENIX_ROOT_URL = cfg.url;
          PHOENIX_WORKING_DIR = workingDir;
          PHOENIX_SQL_DATABASE_URL = "sqlite:///${workingDir}/phoenix.db";
          PHOENIX_ENABLE_AUTH = "true";
          # No FullStory or Scarf pixels, and no web fonts or other public requests.
          PHOENIX_TELEMETRY_ENABLED = "false";
          PHOENIX_ALLOW_EXTERNAL_RESOURCES = "false";
        }
        // lib.optionalAttrs (cfg.retentionDays != null) {
          PHOENIX_DEFAULT_RETENTION_POLICY_DAYS = toString cfg.retentionDays;
        };
        serviceConfig =
          hardening
          // {
            User = user;
            Group = user;
            ExecStart = "${lib.getExe cfg.package} serve";
            EnvironmentFile = "${secretsDir}/phoenix.env";
            StateDirectory = "phoenix";
            Restart = "on-failure";
            RestartSec = "5s";
          }
          // lib.optionalAttrs loopback {
            IPAddressDeny = "any";
            IPAddressAllow = "localhost";
          };
      };

      # Creates one system API key for local clients, once. The server shows a
      # key only at creation, so an existing key file is kept as long as the
      # server still accepts it.
      phoenix-ingest = {
        description = "Create the Phoenix ingest API key";
        wantedBy = [ "phoenix.service" ];
        requires = [ "phoenix.service" ];
        after = [ "phoenix.service" ];
        partOf = [ "phoenix.service" ];
        path = [
          pkgs.curl
          pkgs.jq
        ];
        serviceConfig = hardening // {
          Type = "oneshot";
          RemainAfterExit = true;
          EnvironmentFile = "${secretsDir}/phoenix.env";
          StateDirectory = "phoenix-ingest";
          StateDirectoryMode = "0750";
          ReadWritePaths = [ secretsDir ];
          CapabilityBoundingSet = [ "CAP_CHOWN" ];
        };
        script = ''
          set -o pipefail
          for _ in $(seq 120); do
            curl -sf ${api}/healthz >/dev/null && break
            sleep 2
          done
          key=${cfg.ingestKeyFile}
          valid() {
            [ -s "$key" ] && [ "$(curl -s -o /dev/null -w '%{http_code}' \
              -H "Authorization: Bearer $(cat "$key")" ${api}/v1/projects)" = 200 ]
          }
          if ! valid; then
            jq -n '{data: {name: "ingest", description: "services.phoenix.ingestUsers"}}' |
              curl -sSf -X POST -H "Authorization: Bearer $PHOENIX_ADMIN_SECRET" \
                -H 'Content-Type: application/json' --data @- ${api}/v1/system/api_keys |
              jq -j .data.key > "$key.new"
            mv "$key.new" "$key"
          fi
          printf '{"Authorization": "Bearer %s"}\n' "$(cat "$key")" > ${cfg.ingestHeadersFile}
          cat > ${cfg.ingestEnvFile} <<EOF
          PHOENIX_API_KEY=$(cat "$key")
          PHOENIX_COLLECTOR_ENDPOINT=${api}
          PHOENIX_ENDPOINT=${api}
          EOF
          chmod 0600 ${cfg.ingestEnvFile}
          chgrp ${ingestGroup} ${ingestDir} "$key" ${cfg.ingestHeadersFile}
          chmod 0640 "$key" ${cfg.ingestHeadersFile}
        ''
        + lib.optionalString (cfg.retentionDays != null) setRetention;
      };
    };
  };
}
