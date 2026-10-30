# Arize Phoenix evaluation library (`phoenix.evals`), from the pure-Python
# wheel. Not in nixpkgs. Takes the caller's python package set; see
# ../arize-phoenix-client for the consumption pattern.
{
  lib,
  python3Packages,
  nix-update-script,
}:

python3Packages.buildPythonPackage (finalAttrs: {
  pname = "arize-phoenix-evals";
  version = "3.9.3";
  format = "wheel";

  src = python3Packages.fetchPypi {
    pname = "arize_phoenix_evals";
    inherit (finalAttrs) version;
    format = "wheel";
    dist = "py3";
    python = "py3";
    hash = "sha256-LG38ql9jVfDMGjV4KtIIfDm4WseJYxWRClDt2hwJFno=";
  };

  dependencies = with python3Packages; [
    jsonpath-ng
    openinference-instrumentation
    openinference-semantic-conventions
    opentelemetry-api
    pandas
    pydantic
    pystache
    tqdm
    typing-extensions
  ];

  dontCheckRuntimeDeps = true;
  doCheck = false;
  pythonImportsCheck = [ "phoenix.evals" ];

  passthru = {
    category = "Observability";
    library = true;
    updateScript = nix-update-script { };
  };

  meta = {
    description = "LLM evaluation tools from Arize Phoenix";
    homepage = "https://github.com/Arize-ai/phoenix/tree/main/packages/phoenix-evals";
    license = lib.licenses.elastic20;
    sourceProvenance = [ lib.sourceTypes.binaryBytecode ];
    maintainers = with lib.maintainers; [ jylhis ];
    platforms = lib.platforms.all;
  };
})
