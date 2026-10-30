# End-to-end test for services.langfuse: backing services start, migrations
# apply, the web UI answers on loopback, and an OTLP span posted to the public
# API reaches ClickHouse through the worker. Secrets come from secretFiles and
# hold a backslash and a space. Also checks the unused ClickHouse system logs
# stay off, retention lands on the initial project, and a vanished secret file
# fails the unit instead of being regenerated.
#
# 8 GB guest, several minutes.
{ pkgs, module, ... }:
pkgs.testers.runNixOSTest {
  name = "langfuse-vm";

  nodes.machine =
    { config, ... }:
    {
      imports = [ module ];
      virtualisation = {
        memorySize = 8192;
        cores = 4;
        diskSize = 8192;
      };
      # Same build the module runs, for `clickhouse client`.
      environment.systemPackages = [ config.services.clickhouse.package ];
      services.langfuse = {
        enable = true;
        clickhouseMaxMemory = 2 * 1024 * 1024 * 1024;
        retentionDays = 30;
        ingestUsers = [ "alice" ];
        secretFiles = {
          encryptionKey = "/etc/langfuse-test/encryption-key";
          # A backslash and a space, which an EnvironmentFile would mangle.
          initialUserPassword = "/etc/langfuse-test/user-password";
          projectSecretKey = "/etc/langfuse-test/project-secret-key";
        };
        # Never contacted; the upsert only stores the connection.
        llmConnections.local = {
          baseURL = "http://127.0.0.1:8080/v1";
          models = [ "test-model" ];
          secretKeyFile = "/etc/langfuse-test/llm-key";
        };
      };
      users.users.alice.isNormalUser = true;
      # A copy, not a store symlink, so the test can take it away.
      environment.etc."langfuse-test/encryption-key" = {
        text = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";
        mode = "0400";
      };
      environment.etc."langfuse-test/user-password".text = "pa ss\\word";
      environment.etc."langfuse-test/project-secret-key".text = "vm key\\one";
      environment.etc."langfuse-test/llm-key".text = "sk-test-key-4242";
    };

  testScript = ''
    import json, shlex, time

    machine.wait_for_unit("langfuse-migrate.service", timeout=600)
    machine.wait_for_unit("langfuse-web.service")
    machine.wait_for_unit("langfuse-worker.service")
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:3000/api/public/health", timeout=300)
    # The web UI itself, not only the API, and only on loopback.
    machine.succeed("curl -sf -o /dev/null http://127.0.0.1:3000/auth/sign-in")
    machine.fail("ss -Htln | grep -v -E '127\\.0\\.0\\.1|\\[::1\\]|\\[::ffff:127' | grep -E ':(3000|6380|3900|3901) '")

    # Migrations ran: Prisma's history in PostgreSQL, golang-migrate's in ClickHouse.
    applied = machine.succeed(
        "runuser -u langfuse -- psql -h /run/postgresql -d langfuse -tAc "
        "'SELECT count(*) FROM _prisma_migrations WHERE finished_at IS NOT NULL'"
    ).strip()
    assert int(applied) > 0, f"no prisma migrations applied: {applied!r}"

    # The ingest key pair is readable by ingestUsers members only.
    keys = "/var/lib/langfuse-ingest"
    machine.fail(f"su nobody -s /bin/sh -c 'cat {keys}/secret-key'")
    public = machine.succeed(f"su alice -c 'cat {keys}/public-key'")
    secret = machine.succeed(f"su alice -c 'cat {keys}/secret-key'")
    assert secret == r"sk-lf-vm key\one", f"supplied project key changed: {secret!r}"
    auth = shlex.quote(f"{public}:{secret}")
    # Web created the project with the supplied key, verbatim.
    machine.succeed(f"curl -sf -o /dev/null -u {auth} http://127.0.0.1:3000/api/public/projects")
    # ingest.env reads back verbatim through systemd's parser.
    got = machine.succeed(
        "systemd-run --wait -q -P -p EnvironmentFile=/var/lib/langfuse-secrets/ingest.env "
        "/bin/sh -c 'printf %s \"$LANGFUSE_SECRET_KEY\"'"
    )
    assert got == secret, f"ingest.env key: {got!r}"

    # The initial user signs in with the supplied password, and only with it.
    def signed_in_as(password):
        jar = "/tmp/cookies"
        base = "http://localhost:3000/api/auth"
        machine.succeed(f"rm -f {jar}")
        csrf = json.loads(machine.succeed(f"curl -sf -c {jar} -b {jar} {base}/csrf"))["csrfToken"]
        machine.succeed(
            f"curl -s -o /dev/null -c {jar} -b {jar} "
            "--data-urlencode email=admin@langfuse.local "
            f"--data-urlencode password={shlex.quote(password)} "
            f"--data-urlencode csrfToken={csrf} --data-urlencode json=true "
            f"{base}/callback/credentials"
        )
        session = json.loads(machine.succeed(f"curl -sf -b {jar} {base}/session") or "{}")
        return (session or {}).get("user", {}).get("email")

    assert signed_in_as(r"pa ss\word") == "admin@langfuse.local", "supplied password rejected"
    assert signed_in_as("pa sswor") is None, "wrong password accepted"

    ch_pass = machine.succeed("cat /var/lib/langfuse-secrets/clickhouse-password").strip()
    ch = f"clickhouse client --user langfuse --password {ch_pass}"
    ch_versions = machine.succeed(f"{ch} -q 'SELECT count() FROM schema_migrations'").strip()
    assert int(ch_versions) > 0, f"no clickhouse migrations applied: {ch_versions!r}"

    now = time.time_ns()
    span = {
        "resourceSpans": [{
            "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "vm-test"}}]},
            "scopeSpans": [{
                "scope": {"name": "vm-test"},
                "spans": [{
                    "traceId": "0af7651916cd43dd8448eb211c80319c",
                    "spanId": "b7ad6b7169203331",
                    "name": "vm-test-span",
                    "kind": 1,
                    "startTimeUnixNano": str(now),
                    "endTimeUnixNano": str(now + 1_000_000),
                }],
            }],
        }],
    }
    machine.succeed(f"echo {json.dumps(json.dumps(span))} > /tmp/span.json")
    machine.succeed(
        f"curl -sf -u {auth} -H 'Content-Type: application/json' "
        "--data @/tmp/span.json http://127.0.0.1:3000/api/public/otel/v1/traces"
    )

    # v4 writes OTLP spans to events_full; observations is filled later by
    # the event propagation job, so accept either.
    query = (
        "SELECT (SELECT count() FROM events_full WHERE name = 'vm-test-span')"
        " + (SELECT count() FROM observations WHERE name = 'vm-test-span')"
    )
    machine.wait_until_succeeds(f"test $({ch} -q \"{query}\") -ge 1", timeout=300)

    # The removed system logs are never created; query_log stays. The log
    # tables appear on their first flush, so wait for query_log first.
    machine.wait_until_succeeds(
        f"{ch} -q 'EXISTS TABLE system.query_log' | grep -qx 1",
        timeout=120,
    )
    tables = machine.succeed(
        f"{ch} -q \"SELECT name FROM system.tables WHERE database = 'system' AND name LIKE '%_log'\""
    ).split()
    assert "trace_log" not in tables and "metric_log" not in tables, tables
    assert "query_log" in tables, tables

    # The LLM connection carries the key from secretKeyFile (stored
    # encrypted, shown by its last characters).
    machine.wait_for_unit("langfuse-llm-connections.service", timeout=600)
    shown = machine.succeed(
        "runuser -u langfuse -- psql -h /run/postgresql -d langfuse -tAc "
        "\"SELECT display_secret_key FROM llm_api_keys WHERE provider = 'local'\""
    ).strip()
    assert shown.endswith("4242"), f"LLM key not from secretKeyFile: {shown!r}"

    machine.wait_for_unit("langfuse-retention.service", timeout=600)
    days = machine.succeed(
        "runuser -u langfuse -- psql -h /run/postgresql -d langfuse -tAc "
        "'SELECT retention_days FROM projects'"
    ).strip()
    assert days == "30", f"retention_days = {days!r}"

    # Last, as it stops everything that requires langfuse-secrets: with the
    # supplied encryption key gone, the unit fails and keeps the old copy
    # instead of generating a new key.
    key = "/var/lib/langfuse-secrets/encryption-key"
    before = machine.succeed(f"cat {key}")
    assert before == "0123456789abcdef" * 4, f"supplied key not copied: {before!r}"
    machine.succeed("mv /etc/langfuse-test/encryption-key /etc/langfuse-test/moved")
    machine.fail("systemctl restart langfuse-secrets.service")
    after = machine.succeed(f"cat {key}")
    assert after == before, f"encryption key replaced: {after!r}"
    machine.succeed("touch /etc/langfuse-test/encryption-key")
    machine.fail("systemctl restart langfuse-secrets.service")
    assert machine.succeed(f"cat {key}") == before, "empty file replaced the key"
  '';
}
