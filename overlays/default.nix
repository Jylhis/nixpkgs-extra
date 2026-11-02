# Adds every public package at the top level, built against the consumer's
# nixpkgs (shared dependencies, but a binary cache only hits when the
# consumer's nixpkgs revision matches ours).
final: prev:
(import ../packages {
  pkgs = final;
  inherit (prev) lib;
  extraLib = import ../lib { inherit (prev) lib; };
}).packages
