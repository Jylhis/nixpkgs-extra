{
  lib,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    noFailedAssertions
    runCases
    ;

  pamText = config: service: config.security.pam.services.${service}.text;
  hasU2f = config: service: lib.hasInfix "pam_u2f.so" (pamText config service);

  on = evalNixos [
    module
    { security.u2fKey.enable = true; }
  ];
  off = evalNixos [ module ];
in
runCases "nixos-u2f" {
  disabled = expect (!hasU2f off "sudo") "pam_u2f present with u2fKey disabled";
  enabled = noFailedAssertions on;
  sudo-sufficient = expect (
    builtins.match ".*\nauth sufficient [^ ]*/pam_u2f\\.so.*" (pamText on "sudo") != null
  ) "sudo lacks a sufficient pam_u2f rule";
  not-login = expect (!hasU2f on "login") "pam_u2f leaked into login";
}
