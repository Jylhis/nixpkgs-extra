# End-to-end VM test for services.mem0: the server starts on a local
# PostgreSQL with pgvector, answers its unauthenticated status endpoint on
# loopback, the clients unit bootstraps the admin account and one API key, and
# a memory stored with that key comes back from a search. A stub
# OpenAI-compatible server stands in for the embedder and the chat model, so
# the test needs no network.
{ pkgs, module, ... }:
let
  stub = pkgs.writers.writePython3 "mem0-stub" { flakeIgnore = [ "E501" ]; } ''
    import hashlib
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer

    DIMS = 8


    def embed(text):
        digest = hashlib.sha256(text.encode()).digest()
        return [digest[i] / 255.0 + 0.01 for i in range(DIMS)]


    class Handler(BaseHTTPRequestHandler):
        def do_POST(self):
            body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            if self.path.endswith("/embeddings"):
                texts = body["input"] if isinstance(body["input"], list) else [body["input"]]
                out = {
                    "object": "list",
                    "model": body["model"],
                    "data": [
                        {"object": "embedding", "index": i, "embedding": embed(t)}
                        for i, t in enumerate(texts)
                    ],
                    "usage": {"prompt_tokens": 1, "total_tokens": 1},
                }
            else:
                out = {
                    "id": "stub",
                    "object": "chat.completion",
                    "created": 0,
                    "model": body["model"],
                    "choices": [
                        {
                            "index": 0,
                            "finish_reason": "stop",
                            "message": {"role": "assistant", "content": '{"facts": []}'},
                        }
                    ],
                    "usage": {"prompt_tokens": 1, "completion_tokens": 1, "total_tokens": 2},
                }
            data = json.dumps(out).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)


    HTTPServer(("127.0.0.1", 9999), Handler).serve_forever()
  '';
in
pkgs.testers.runNixOSTest {
  name = "mem0-vm";

  nodes.machine = {
    imports = [ module ];
    virtualisation.memorySize = 2048;

    systemd.services.mem0-stub = {
      wantedBy = [ "multi-user.target" ];
      before = [ "mem0.service" ];
      serviceConfig.ExecStart = stub;
    };

    services.mem0 = {
      enable = true;
      clientUsers = [ "alice" ];
      embedder = {
        model = "stub-embed";
        baseUrl = "http://127.0.0.1:9999/v1";
        dims = 8;
      };
      llm = {
        model = "stub-chat";
        baseUrl = "http://127.0.0.1:9999/v1";
      };
    };
    users.users.alice.isNormalUser = true;

    # Non-default port: mem0-db must reach the socket of this port.
    services.postgresql.settings.port = 5433;
  };

  testScript = ''
    import json

    machine.wait_for_unit("mem0.service")
    machine.wait_for_open_port(8888, "127.0.0.1")

    api = "http://127.0.0.1:8888"

    # The status endpoint needs no key and reaches the auth database.
    status = json.loads(machine.succeed(f"curl -sf {api}/auth/setup-status"))
    assert "needsSetup" in status, status

    machine.wait_for_unit("mem0-clients.service")

    # The client key is readable by clientUsers members only.
    keyfile = "/var/lib/mem0-clients/api-key"
    machine.fail(f"su nobody -s /bin/sh -c 'cat {keyfile}'")
    key = machine.succeed(f"su alice -c 'cat {keyfile}'").strip()
    assert key.startswith("m0sk_"), key

    auth = f"-H 'X-API-Key: {key}' -H 'Content-Type: application/json'"

    # No key, no access.
    code = machine.succeed(f"curl -s -o /dev/null -w '%{{http_code}}' '{api}/memories?user_id=u'").strip()
    assert code == "401", code

    add = {"messages": [{"role": "user", "content": "I like green tea"}], "user_id": "u", "infer": False}
    machine.succeed(f"echo {json.dumps(json.dumps(add))} > /tmp/add.json")
    machine.succeed(f"curl -sf {auth} --data @/tmp/add.json {api}/memories")

    search = {"query": "I like green tea", "filters": {"user_id": "u"}, "top_k": 3}
    machine.succeed(f"echo {json.dumps(json.dumps(search))} > /tmp/search.json")
    out = machine.succeed(f"curl -sf {auth} --data @/tmp/search.json {api}/search")
    assert "green tea" in out, out

    # The database really listens on the non-default port.
    machine.succeed("ss -ltnH 'sport = :5433' | grep -q .")
    machine.fail("ss -ltnH 'sport = :5432' | grep -q .")

    # The server listens on loopback only.
    listen = machine.succeed("ss -ltnH 'sport = :8888'").split()
    assert "127.0.0.1:8888" in listen, listen
  '';
}
