# Every overrides/<attr>.nix: a nixpkgs attribute replaced in place by
# overlays.overrides. Each file is `{ final, prev }: <derivation>` and its
# first line, a `# ` comment, is the description in the README.
#
# `dir` points the same loader at another override directory
# (llm-agents-overrides/).
{
  lib,
  dir ? ./.,
}:
let
  files = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) (builtins.readDir dir);

  names = map (lib.removeSuffix ".nix") (lib.attrNames files);
in
{
  inherit names;

  overlay =
    final: prev: lib.genAttrs names (name: import (dir + "/${name}.nix") { inherit final prev; });

  descriptions = lib.genAttrs names (
    name:
    lib.removePrefix "# " (lib.head (lib.splitString "\n" (builtins.readFile (dir + "/${name}.nix"))))
  );
}
