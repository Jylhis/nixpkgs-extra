{
  lib,
  module,
  nixosModules,
  testLib,
  extraLib,
  pkgs,
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

  on = evalNixos [
    module
    { services.openviking-server.enable = true; }
  ];
  off = evalNixos [ module ];
  exposeRequested = evalNixos [
    module
    {
      services.openviking-server = {
        enable = true;
        exposeViaTailscale = true;
      };
      services.tailscale.enable = true;
    }
  ];

  # With this repository's expose module and its Tailscale backend.
  withExpose = evalNixos [
    module
    nixosModules.expose
    {
      services.openviking-server = {
        enable = true;
        exposeViaTailscale = true;
      };
      services.tailscale.enable = true;
      services.expose.tailscale.enable = true;
    }
  ];
  exposeWithoutBackend = evalNixos [
    module
    nixosModules.expose
    {
      services.openviking-server = {
        enable = true;
        exposeViaTailscale = true;
      };
    }
  ];

  ovConfWith =
    embeddingExtra: fallback:
    let
      local = {
        provider = "openai";
        apiBase = "http://127.0.0.1:8080/v1";
        apiKey = "local";
      };
    in
    extraLib.openviking.mkOvConf {
      workspace = "/ws";
      embedding =
        local
        // {
          model = "qwen3-embedding-4b";
          dimension = 2560;
          inherit fallback;
        }
        // embeddingExtra;
      vlm = local // {
        model = "qwen3.6-35b-a3b";
        fallback = null;
      };
    };
  ovConf = ovConfWith { };
  ovFallback = {
    provider = "openai";
    model = "qwen/qwen3-embedding-4b";
    apiBase = "https://openrouter.ai/api/v1";
    apiKey = null;
  };
in
runCases "nixos-openviking-server" {
  off-by-default = expect (!(off.systemd.services ? openviking-server)) "unit defined without enable";
  enables-unit = allOf [
    (expect (on.systemd.services ? openviking-server) "unit missing")
    (noFailedAssertions on)
    (expect on.systemd.services.openviking-server.serviceConfig.DynamicUser "not a dynamic user")
  ];
  # No services.expose declared here; evaluating must not need it.
  no-expose-option = expect (
    !(on.services ? expose)
  ) "services.expose appeared without a declaring module";
  expose-needs-option = expect (lib.any (m: lib.hasInfix "needs the expose" m) (
    testLib.failedAssertions exposeRequested
  )) "exposeViaTailscale did not assert without services.expose";
  expose-needs-backend = expect (lib.any (m: lib.hasInfix "services.expose.tailscale.enable" m) (
    testLib.failedAssertions exposeWithoutBackend
  )) "exposeViaTailscale did not assert without the tailscale backend";
  expose-when-declared = allOf [
    (noFailedAssertions withExpose)
    (expect (
      withExpose.services.expose.services.openviking.upstream == "http://127.0.0.1:1933"
    ) "services.expose.services.openviking not set")
    (expect (lib.hasInfix "--service=svc:openviking --https=443 http://127.0.0.1:1933" (lib.head withExpose.systemd.services.tailscale-serve-expose.restartTriggers).text) "svc:openviking not served")
  ];
  package-default = expect (
    on.services.openviking-server.package.pname == "openviking-server"
  ) "package default does not resolve to openviking-server";
  exec-start = expect (lib.hasInfix "--port 1933" on.systemd.services.openviking-server.serviceConfig.ExecStart) "port not passed to ExecStart";
  firewall-closed-by-default = expect (
    !(lib.elem 1933 on.networking.firewall.allowedTCPPorts)
  ) "port opened by default";

  # No `credentials` without a fallback (the conf stays as before), two
  # dimension-free credentials with one.
  openviking-no-fallback =
    let
      conf = ovConf null;
    in
    expect (
      !(conf.embedding.dense ? credentials) && !(conf.vlm ? credentials)
    ) "credentials rendered without a fallback";
  openviking-fallback =
    let
      inherit ((ovConf ovFallback).embedding) dense;
      creds = dense.credentials;
    in
    allOf [
      (expect (
        map (c: c.id) creds == [
          "primary"
          "fallback"
        ]
      ) "credentials are not [primary fallback]")
      (expect (lib.all (c: !(c ? dimension)) creds) "a credential carries a dimension")
      (expect (dense.dimension == 2560) "dense lost its dimension")
    ];
  # max_input_tokens sits at the embedding level (0.5.1 ignores it in
  # dense), and only when set.
  openviking-embedding-max-input =
    let
      capped = (ovConfWith { maxInputTokens = 2560; } null).embedding;
    in
    allOf [
      (expect (
        !((ovConf null).embedding ? max_input_tokens)
      ) "max_input_tokens rendered without maxInputTokens")
      (expect (capped.max_input_tokens == 2560) "embedding lost max_input_tokens")
      (expect (!(capped.dense ? max_input_tokens)) "max_input_tokens still in dense")
    ];
}
