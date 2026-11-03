# End-to-end VM test for services.phoenix: the server starts with
# authentication on, answers HTTP on loopback, phoenix-ingest creates one
# system API key that only an ingestUsers member can read, one protobuf OTLP
# span posted to /v1/traces with that key lands in the named project and reads
# back through the REST API, and the same calls without the key get 401.
{ pkgs, module, ... }:
let
  inherit (pkgs) testers python3;
  # Builds the protobuf body that curl posts; the exporter SDK is not needed.
  makeSpan = python3.withPackages (ps: [ ps.opentelemetry-proto ]);
in
testers.runNixOSTest {
  name = "phoenix-vm";

  nodes.machine =
    { pkgs, ... }:
    {
      imports = [ module ];
      virtualisation.memorySize = 2048;
      environment.systemPackages = [
        makeSpan
        pkgs.jq
      ];
      services.phoenix = {
        enable = true;
        ingestUsers = [ "alice" ];
      };
      users.users.alice.isNormalUser = true;

      # The same database with a retention setting: Phoenix keeps the policy
      # it already seeded, so only the API patch can change it.
      # keepProjects creates the project and moves it to a policy with no limit.
      specialisation.retained.configuration.services.phoenix = {
        retentionDays = 30;
        keepProjects = [ "kept-project" ];
      };
    };

  testScript = ''
    import json

    machine.wait_for_unit("phoenix.service", timeout=300)
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:6006/healthz", timeout=300)
    machine.wait_for_unit("phoenix-ingest.service", timeout=300)

    # The gRPC collector listens on loopback only.
    # (grpc may report the address as the v4-mapped [::ffff:127.0.0.1]).
    grpc = [l for l in machine.succeed("ss -ltnH").splitlines() if ":4317 " in l]
    assert grpc and all("127.0.0.1" in l for l in grpc), grpc

    # Telemetry and external requests are off.
    env = machine.succeed("systemctl show phoenix -p Environment")
    for want in (
        "PHOENIX_ENABLE_AUTH=true",
        "PHOENIX_TELEMETRY_ENABLED=false",
        "PHOENIX_ALLOW_EXTERNAL_RESOURCES=false",
        "PHOENIX_GRPC_HOST=127.0.0.1",
    ):
        assert want in env, (want, env)

    # The key is readable by ingestUsers members only; the secrets stay root-only.
    keys = "/var/lib/phoenix-ingest"
    machine.fail(f"su nobody -s /bin/sh -c 'cat {keys}/api-key'")
    machine.fail("su alice -c 'ls /var/lib/phoenix-secrets'")
    key = machine.succeed(f"su alice -c 'cat {keys}/api-key'").strip()
    headers = json.loads(machine.succeed(f"su alice -c 'cat {keys}/otlp-headers.json'"))
    assert headers == {"Authorization": f"Bearer {key}"}, headers
    env_file = machine.succeed("cat /var/lib/phoenix-secrets/ingest.env")
    assert f"PHOENIX_API_KEY={key}" in env_file, env_file
    assert "PHOENIX_COLLECTOR_ENDPOINT=http://127.0.0.1:6006" in env_file, env_file

    # An existing database keeps its unlimited default retention policy until
    # retentionDays is set; then the ingest unit patches it.
    admin = machine.succeed("cat /var/lib/phoenix-secrets/admin-secret").strip()
    gql = json.dumps({"query": (
        'query { node(id: "UHJvamVjdFRyYWNlUmV0ZW50aW9uUG9saWN5OjA=") '
        "{ ... on ProjectTraceRetentionPolicy { rule { ... on TraceRetentionRuleMaxDays { maxDays } } } } }"
    )})

    def retention_days():
        out = machine.succeed(
            f"curl -sf -X POST -H 'Authorization: Bearer {admin}' "
            f"-H 'Content-Type: application/json' -d '{gql}' http://127.0.0.1:6006/graphql"
        )
        return json.loads(out)["data"]["node"]["rule"]["maxDays"]

    assert retention_days() == 0, retention_days()
    machine.succeed("/run/booted-system/specialisation/retained/bin/switch-to-configuration test")
    machine.wait_for_unit("phoenix-ingest.service", timeout=300)
    machine.wait_until_succeeds("curl -sf http://127.0.0.1:6006/healthz", timeout=300)
    machine.wait_until_succeeds(
        "systemctl show phoenix -p Environment | grep -q PHOENIX_DEFAULT_RETENTION_POLICY_DAYS=30"
    )
    machine.wait_until_succeeds("systemctl is-active phoenix-ingest.service", timeout=300)
    assert retention_days() == 30, retention_days()

    kept_gql = json.dumps({"query": (
        "query { projects { edges { node { name traceRetentionPolicy { name "
        "rule { ... on TraceRetentionRuleMaxDays { maxDays } } } } } } }"
    )})

    def kept_policy():
        out = machine.succeed(
            f"curl -sf -X POST -H 'Authorization: Bearer {admin}' "
            f"-H 'Content-Type: application/json' -d '{kept_gql}' http://127.0.0.1:6006/graphql"
        )
        nodes = {e["node"]["name"]: e["node"] for e in json.loads(out)["data"]["projects"]["edges"]}
        return nodes["kept-project"]["traceRetentionPolicy"]

    assert kept_policy() == {"name": "keep-forever", "rule": {"maxDays": 0}}, kept_policy()

    # A second run keeps the key and patches the existing keep-forever policy.
    machine.succeed("systemctl restart phoenix-ingest.service")
    assert machine.succeed(f"cat {keys}/api-key").strip() == key
    assert kept_policy() == {"name": "keep-forever", "rule": {"maxDays": 0}}, kept_policy()

    machine.succeed(
        "python3 - <<'PY'\n"
        "import time\n"
        "from opentelemetry.proto.collector.trace.v1.trace_service_pb2 import ExportTraceServiceRequest\n"
        "r = ExportTraceServiceRequest()\n"
        "rs = r.resource_spans.add()\n"
        "for k, v in (('service.name', 'vm-test'), ('openinference.project.name', 'vm-project')):\n"
        "    a = rs.resource.attributes.add(); a.key = k; a.value.string_value = v\n"
        "s = rs.scope_spans.add().spans.add()\n"
        "s.trace_id = bytes.fromhex('0af7651916cd43dd8448eb211c80319c')\n"
        "s.span_id = bytes.fromhex('b7ad6b7169203331')\n"
        "s.name = 'vm-test-span'; s.kind = 1\n"
        "s.start_time_unix_nano = time.time_ns(); s.end_time_unix_nano = s.start_time_unix_nano + 1000000\n"
        "open('/tmp/span.pb', 'wb').write(r.SerializeToString())\n"
        "PY"
    )
    post = (
        "curl -s -o /dev/null -w '%{http_code}' -X POST "
        "-H 'Content-Type: application/x-protobuf' --data-binary @/tmp/span.pb "
        "http://127.0.0.1:6006/v1/traces"
    )
    assert machine.succeed(post) == "401", "span accepted without a key"
    machine.succeed(post.replace("curl -s", f"curl -s -H 'Authorization: Bearer {key}'") + " | grep -qx 200")

    read = "http://127.0.0.1:6006/v1/projects/vm-project/spans"
    assert machine.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' {read}") == "401"
    machine.wait_until_succeeds(
        f"curl -sf -H 'Authorization: Bearer {key}' {read} | jq -e '.data[] | select(.name == \"vm-test-span\")'",
        timeout=120,
    )
  '';
}
