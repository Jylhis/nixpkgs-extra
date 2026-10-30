# Arize Phoenix Python client (`phoenix.client`), from the pure-Python wheel.
#
# Not in nixpkgs. Takes the caller's python package set
# so any interpreter can add it: `python3.withPackages (ps: [ (callPackage
# ../arize-phoenix-client { python3Packages = ps; }) ])`.
{
  lib,
  python3Packages,
  nix-update-script,
}:

python3Packages.buildPythonPackage (finalAttrs: {
  pname = "arize-phoenix-client";
  version = "3.5.0";
  format = "wheel";

  src = python3Packages.fetchPypi {
    pname = "arize_phoenix_client";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-230FtpLbA4nY0zBtWVeXkyZPjsOy9+nl1yTpFgrHj3I=";
  };

  dependencies = with python3Packages; [
    httpx
    openinference-instrumentation
    openinference-semantic-conventions
    opentelemetry-exporter-otlp
    opentelemetry-sdk
    tqdm
    typing-extensions
  ];

  # Upstream floors sit a little above the pinned nixpkgs set.
  dontCheckRuntimeDeps = true;
  doCheck = false;
  pythonImportsCheck = [ "phoenix.client" ];

  passthru = {
    category = "Observability";
    library = true;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "Client for the Arize Phoenix LLM observability API";
    homepage = "https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-client";
    license = lib.licenses.elastic20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.all;
  };
})
