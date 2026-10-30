# Shared Phoenix environment for every traced AI process, used by the Home
# Manager module (modules/home/phoenix) and available to other services as
# `lib.phoenixEnv`. The names are the ones the Arize
# coding-harness-tracing hooks and phoenix-mcp read. The key file is read at
# run time, so no secret enters the store; an unreadable file exports nothing
# and the hooks fail open.
{ lib }:
{
  # Non-secret values.
  env =
    {
      endpoint,
      project,
      userId ? null,
      extraEnv ? { },
    }:
    {
      PHOENIX_ENDPOINT = endpoint;
      PHOENIX_PROJECT = project;
      ARIZE_TRACE_ENABLED = "true";
    }
    // lib.optionalAttrs (userId != null) { ARIZE_USER_ID = userId; }
    // extraEnv;

  # Shell that exports the API key from its file.
  keyExports =
    { apiKeyFile }:
    ''
      if [ -r ${lib.escapeShellArg apiKeyFile} ]; then
        export PHOENIX_API_KEY="$(cat ${lib.escapeShellArg apiKeyFile})"
      fi
    '';

  # Shell that exports each value unless the environment already sets it.
  # `export VAR="${VAR:-default}"`, not a bare `:=` expansion, which assigns
  # but never exports.
  defaultExports =
    env:
    lib.concatStrings (
      lib.mapAttrsToList (n: v: ''
        export ${n}="''${${n}:-${v}}"
      '') env
    );
}
