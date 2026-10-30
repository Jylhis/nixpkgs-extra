# Adds every public package at the top level, built against the consumer's
# nixpkgs (shared dependencies, but a binary cache only hits when the
# consumer's nixpkgs revision matches ours).
{ fenixFor }:
final: prev:
(import ../packages {
  pkgs = final;
  inherit (prev) lib;
  fenix = fenixFor final.stdenv.hostPlatform.system;
  extraLib = import ../lib { inherit (prev) lib; };
}).packages
