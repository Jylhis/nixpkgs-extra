{ lib }:
{
  # The `ocr` command of programs.open-code-review: a wrapper that sets the OTEL_*
  # variables (the OTLP protocol and headers have no config key), reading the headers
  # file at run time. telemetry has the shape of programs.open-code-review.telemetry.
  # The Home Manager module installs it; a host that installs programs in another
  # profile builds the same wrapper here and sets installWrapper = false.
  mkWrapper =
    {
      pkgs,
      package,
      telemetry ? {
        enable = false;
      },
    }:
    let
      resourceAttributes = lib.concatStringsSep "," (
        lib.mapAttrsToList (k: v: "${k}=${v}") telemetry.resourceAttributes
      );
    in
    # Without a complete provider in the config file, OCR falls back to Claude
    # Code's ANTHROPIC_* variables. Those credentials are for the Claude Code
    # harness only, so the wrapper drops them and OCR fails instead.
    #
    # A missing or unreadable headers file (the backend not started yet) runs the
    # review without telemetry rather than failing it.
    pkgs.writeShellScriptBin "ocr" (
      ''
        unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_API_KEY ANTHROPIC_MODEL
      ''
      + lib.optionalString telemetry.enable ''
        if headers=$(${lib.getExe pkgs.jq} -r \
            'to_entries | map("\(.key)=\(.value | @uri)") | join(",")' \
            ${lib.escapeShellArg telemetry.headersFile} 2>/dev/null); then
          export OCR_ENABLE_TELEMETRY=1
          export OTEL_EXPORTER_OTLP_PROTOCOL=http/protobuf
          export OTEL_EXPORTER_OTLP_ENDPOINT=${lib.escapeShellArg telemetry.endpoint}
          export OTEL_EXPORTER_OTLP_HEADERS="$headers"
          export OTEL_SERVICE_NAME=${lib.escapeShellArg telemetry.serviceName}
          ${lib.optionalString (!telemetry.metrics.enable) "export OTEL_METRICS_EXPORTER=none"}
          ${lib.optionalString (telemetry.resourceAttributes != { }) ''
            export OTEL_RESOURCE_ATTRIBUTES=${lib.escapeShellArg resourceAttributes}
          ''}
        fi
      ''
      + ''
        exec ${lib.getExe package} "$@"
      ''
    );
}
