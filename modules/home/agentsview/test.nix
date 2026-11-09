{
  lib,
  pkgs,
  module,
  homeModules,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalHome
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  stub = pkgs.writeShellScriptBin "agentsview" "true";

  off = evalHome [ module ];

  noPackage = evalHome [
    module
    { services.agentsview.enable = true; }
  ];

  on = evalHome [
    module
    {
      services.agentsview = {
        enable = true;
        package = stub;
        port = 9000;
        publicOrigins = [ "http://agentsview.example.org" ];
        dataDir = "/var/lib/alice/av";
        environment.HTTP_PROXY = "http://127.0.0.1:9";
      };
    }
  ];

  unit = on.systemd.user.services.agentsview.Service;
  execStart = lib.concatStringsSep " " (lib.toList unit.ExecStart);

  plain = evalHome [
    module
    {
      services.agentsview = {
        enable = true;
        package = stub;
        sandbox.enable = false;
        lowPriority = false;
        maintenance.enable = false;
      };
    }
  ];
  plainUnit = plain.systemd.user.services.agentsview.Service;

  llamaOn =
    extra:
    evalHome [
      module
      homeModules.llama-servers
      {
        services.llamaServers = {
          enable = true;
          masterKeyFile = "/run/user/1000/bifrost-key";
          models.embedder = {
            kind = "embedding";
            model = "/var/cache/models/embedder.gguf";
          };
          anthropicApiKeyFile = "/run/user/1000/anthropic-key";
          anthropicModels.claude-fast = "claude-fast-1";
        };
        services.agentsview = {
          enable = true;
          package = stub;
          llama = {
            enable = true;
            embeddingModel = "embedder";
            dimension = 1024;
            extractModel = "claude-fast";
          }
          // extra;
        };
      }
    ];

  withLlama = llamaOn { queryPrefix = "Query:"; };
  llamaUnit = withLlama.systemd.user.services.agentsview;
  settings = withLlama.services.agentsview.settings;
  offSettings = on.services.agentsview.settings;
  rejected = config: !(builtins.tryEval config.services.agentsview.enable).success;

  mergeCheck =
    pkgs.runCommand "agentsview-config-merge"
      {
        nativeBuildInputs = [
          on.services.agentsview.configMerge
          pkgs.remarshal
          pkgs.jq
        ];
      }
      ''
        fail() { echo "agentsview-config-merge: $*" >&2; exit 1; }

        cat > config.toml <<'TOML'
        auth_token = "tok"
        cursor_secret = "sec"
        [other]
        x = 1
        [vector]
        foo = "stale"
        [vector.embeddings]
        model = "old"
        TOML
        cp config.toml dry-run.toml
        cat > settings.json <<'JSON'
        {
          "vector": {
            "enabled": true,
            "embeddings": {
              "model": "embedder",
              "dimension": 4096,
              "query_prefix": "Instruct: q\nQuery:",
              "servers": {"gateway": {"endpoint": "http://127.0.0.1:1/v1", "api_key_env": "K"}}
            }
          },
          "recall": {"extract": {"enabled": true, "model": "m"}}
        }
        JSON

        test "$(agentsview-config-merge config.toml settings.json)" = changed \
          || fail "first merge did not report a change"
        remarshal -if toml -of json config.toml > result.json || fail "merged config is invalid TOML"
        jq -e '.auth_token == "tok" and .cursor_secret == "sec"' result.json \
          || fail "secrets were not preserved"
        jq -e '.other.x == 1' result.json || fail "unmanaged table was not preserved"
        jq -e '(.vector | has("foo")) == false' result.json \
          || fail "stale managed key survived replacement"
        jq -e '.vector.embeddings.model == "embedder"' result.json \
          || fail "embedding model was not replaced"
        jq -e '.vector.embeddings.dimension == 4096' result.json \
          || fail "embedding dimension is not the integer 4096"
        jq -e '.vector.embeddings.query_prefix | contains("\n")' result.json \
          || fail "query prefix lost its newline"
        jq -e '.recall.extract.enabled == true' result.json || fail "recall table was not added"
        test "$(stat -c %a config.toml)" = 600 || fail "config mode is not 600"
        test -e config.toml.lock || fail "config.toml.lock was not created"

        cp config.toml first.toml
        test -z "$(agentsview-config-merge config.toml settings.json)" \
          || fail "an unchanged merge reported a change"
        cmp first.toml config.toml || fail "second merge changed config bytes"
        test -z "$(ls config.toml.* | grep -v '\.lock$' || true)" || fail "a temp file was left behind"

        printf 'auth_token = "tok"\n' > stale.toml
        : > stale.toml.tmp
        chmod 644 stale.toml stale.toml.tmp
        agentsview-config-merge stale.toml settings.json > /dev/null || fail "stale merge failed"
        test "$(stat -c %a stale.toml)" = 600 || fail "a stale temp file leaked its mode"

        agentsview-config-merge missing.toml settings.json || fail "missing config merge failed"
        remarshal -if toml -of json missing.toml > fresh.json || fail "new config is invalid TOML"
        jq -e --slurpfile settings settings.json '. == $settings[0]' fresh.json \
          || fail "new config does not contain exactly the managed tables"

        cp dry-run.toml before-dry-run.toml
        DRY_RUN=1 agentsview-config-merge dry-run.toml settings.json || fail "dry run failed"
        cmp before-dry-run.toml dry-run.toml || fail "dry run changed config bytes"
        test ! -e dry-run.toml.lock || fail "dry run created the lock file"
        DRY_RUN=1 agentsview-config-merge fresh/dir/config.toml settings.json || fail "fresh dry run failed"
        test ! -e fresh || fail "dry run created the data directory"
        touch $out
      '';

  cases = runCases "home-agentsview-cases" {
    off-by-default = allOf [
      (expect (!off.services.agentsview.enable) "enabled without enable = true")
      (noFailedAssertions off)
    ];
    # Home Manager throws its failed assertions on any read of the config.
    package-null-asserts = expect (
      !(builtins.tryEval noPackage.services.agentsview.enable).success
    ) "enabling without a package does not assert";
    stub-package = allOf [
      (noFailedAssertions on)
      (expect (builtins.elem stub on.home.packages) "package not installed")
      (expect (builtins.match ".* --port 9000 .*" execStart != null) "port not rendered")
      (expect (
        builtins.match ".*--public-origin.*agentsview.example.org.*" execStart != null
      ) "public origin not rendered")
      (expect (builtins.elem "AGENTSVIEW_DATA_DIR=/var/lib/alice/av" unit.Environment) "dataDir not rendered")
      (expect (builtins.elem "HTTP_PROXY=http://127.0.0.1:9" unit.Environment) "environment not rendered")
      (expect (builtins.elem "-/var/lib/alice/.claude" unit.ReadOnlyPaths) "session roots not read-only")
    ];
    sandbox = allOf [
      (expect (unit.ProtectHome == "read-only") "home not read-only")
      (expect (unit.ProtectSystem == "strict") "system not strict")
      (expect (unit.ReadWritePaths == [ "/var/lib/alice/av" ]) "dataDir not the only writable path")
      (expect (builtins.elem "XDG_CACHE_HOME=/var/lib/alice/av/cache" unit.Environment) "cache not under dataDir")
      (expect (unit.Nice == 10 && unit.CPUWeight == 20) "low priority not applied")
      (expect (unit.MemoryHigh == "2G" && unit.MemoryMax == "4G") "memory limits")
      (expect (
        on.systemd.user.services.agentsview-compact.Service.ProtectHome == "read-only"
      ) "maintenance unit not sandboxed")
    ];
    sandbox-off = allOf [
      (expect (!(plainUnit ? ProtectHome)) "sandbox applied while off")
      (expect (!(plainUnit ? Nice)) "low priority applied while off")
      (expect (
        !(builtins.any (lib.hasPrefix "XDG_CACHE_HOME") plainUnit.Environment)
      ) "XDG cache set without sandbox")
      (expect (!(plain.systemd.user.services ? agentsview-compact)) "maintenance unit while off")
    ];
    maintenance = allOf [
      (expect (
        on.systemd.user.timers.agentsview-secrets-scan.Timer.OnCalendar == "daily"
      ) "secrets scan schedule")
      (expect (on.systemd.user.timers.agentsview-compact.Timer.OnCalendar == "weekly") "compact schedule")
      (expect (lib.hasSuffix "secrets scan --backfill" (lib.concatStringsSep " " (lib.toList on.systemd.user.services.agentsview-secrets-scan.Service.ExecStart))) "secrets scan command")
    ];
    activation = allOf [
      (expect (on.home.activation ? agentsviewConfig) "config merge step missing")
      (expect (on.home.activation ? agentsviewRestart) "restart step missing")
      (expect (lib.hasInfix "agentsview-config-merge" on.home.activation.agentsviewConfig.data) "merge script not run")
    ];
    llama-off-writes-disabled-tables = allOf [
      (expect (offSettings.vector.enabled == false) "vector not written disabled")
      (expect (offSettings.recall.extract.enabled == false) "recall not written disabled")
      (expect (
        !(on.systemd.user.services.agentsview.Service ? LoadCredential)
      ) "credential without llama")
    ];
    llama = allOf [
      (noFailedAssertions withLlama)
      (expect (settings.vector.enabled && settings.recall.extract.enabled) "tables not enabled")
      (expect (settings.vector.embeddings.model == "embedder") "embedding model")
      (expect (settings.vector.embeddings.dimension == 1024) "dimension")
      (expect (settings.vector.embeddings.query_prefix == "Query:") "query prefix")
      (expect (settings.recall.extract.model == "claude-fast") "extract model")
      (expect (
        settings.vector.embeddings.servers.gateway.endpoint == "http://127.0.0.1:4080/v1"
      ) "embeddings endpoint is not the gateway")
      (expect (
        settings.recall.extract.servers.gateway.endpoint == "http://127.0.0.1:4080/v1"
      ) "extract endpoint is not the gateway")
      (expect (
        settings.vector.embeddings.servers.gateway.api_key_env == "AGENTSVIEW_GATEWAY_KEY"
      ) "key is not read from the environment")
      (expect (
        llamaUnit.Service.LoadCredential == [ "gateway-key:/run/user/1000/bifrost-key" ]
      ) "gateway key not a credential")
      (expect (llamaUnit.Unit.After == [ "bifrost.service" ]) "unit not ordered after the gateway")
      (expect (llamaUnit.Unit.Wants == [ "bifrost.service" ]) "unit does not pull in the gateway")
      (expect (!(settings.vector.embeddings ? input_suffix)) "unexpected input_suffix")
      (expect (!(lib.hasInfix "bifrost-key" (builtins.toJSON settings))) "key path leaked into settings")
      (expect (
        !((llamaOn { }).services.agentsview.settings.vector.embeddings ? query_prefix)
      ) "query prefix rendered when null")
    ];
    llama-overridable = expect (
      (evalHome [
        module
        homeModules.llama-servers
        {
          services.llamaServers = {
            enable = true;
            masterKeyFile = "/k";
            models.e.kind = "embedding";
          };
          services.agentsview = {
            enable = true;
            package = stub;
            llama = {
              enable = true;
              embeddingModel = "e";
              extractModel = "e";
              dimension = 8;
            };
            settings.vector.embeddings.max_input_chars = 100;
          };
        }
      ]).services.agentsview.settings.vector.embeddings.max_input_chars == 100
    ) "a leaf of the managed table is not overridable";
    llama-assertions = allOf [
      (expect (rejected (evalHome [
        module
        homeModules.llama-servers
        {
          services.llamaServers.enable = false;
          services.agentsview = {
            enable = true;
            package = stub;
            llama = {
              enable = true;
              embeddingModel = "x";
              extractModel = "y";
              dimension = 8;
            };
          };
        }
      ])) "llama without llamaServers accepted")
      (expect (rejected (llamaOn {
        extractModel = "nope";
      })) "unknown extract model accepted")
    ];
  };
in
pkgs.runCommand "home-agentsview" { inherit cases mergeCheck; } "touch $out"
