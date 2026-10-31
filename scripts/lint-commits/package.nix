# lint-commits, wrapped with the subject prefixes this repo knows: every
# package (internal ones too), override, llm-agents override and module.
# `nix run .#lint-commits -- <base>`; the build runs the Go tests.
{ pkgs, repo }:
let
  inherit (pkgs) lib;

  dirNames =
    dir: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir dir));
  overrideNames = dir: (import dir { inherit lib; }).names;
  moduleNames = kind: lib.attrNames (removeAttrs repo."${kind}Modules" [ "default" ]);

  known = pkgs.writeText "lint-commits-known" (
    lib.concatLines (
      dirNames ../../packages
      ++ overrideNames ../../overrides
      ++ map (name: "llm-agents.${name}") (overrideNames ../../llm-agents-overrides)
      ++ map (name: "nixos/${name}") (moduleNames "nixos")
      ++ lib.concatMap (name: [
        "home/${name}"
        "home-manager/${name}"
      ]) (moduleNames "home")
    )
  );

  unwrapped = pkgs.buildGoModule {
    pname = "lint-commits";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.fileFilter (file: lib.hasSuffix ".go" file.name || file.name == "go.mod") ./.;
    };
    vendorHash = null;
    meta.mainProgram = "lint-commits";
  };
in
pkgs.writeShellApplication {
  name = "lint-commits";
  runtimeInputs = [ pkgs.git ];
  text = ''exec ${lib.getExe unwrapped} -known ${known} "$@"'';
}
