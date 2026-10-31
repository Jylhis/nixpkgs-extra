# Arize Phoenix OpenTelemetry helpers (`phoenix.otel`), from the pure-Python
# wheel. Not in nixpkgs. Takes the caller's python package set; see
# ../arize-phoenix-client for the consumption pattern.
{
  lib,
  fetchPypi,
  python3Packages,
  nix-update-script,
}:

python3Packages.buildPythonPackage (finalAttrs: {
  pname = "arize-phoenix-otel";
  version = "0.17.2";
  format = "wheel";

  src = fetchPypi {
    pname = "arize_phoenix_otel";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-1Nh7mNZ/qSjZVM27HQv58195osZXKuesofbEMFEPL5k=";
  };

  dependencies = with python3Packages; [
    openinference-instrumentation
    openinference-semantic-conventions
    opentelemetry-exporter-otlp
    opentelemetry-exporter-otlp-proto-http
    opentelemetry-proto
    opentelemetry-sdk
    opentelemetry-semantic-conventions
    typing-extensions
    wrapt
  ];

  # Upstream asks for opentelemetry >= 1.45; nixpkgs carries 1.43.
  dontCheckRuntimeDeps = true;
  doCheck = false;
  pythonImportsCheck = [ "phoenix.otel" ];

  passthru = {
    category = "Observability";
    library = true;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "OpenTelemetry wrappers for sending traces to Arize Phoenix";
    homepage = "https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-otel";
    license = lib.licenses.elastic20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.all;
  };
})
