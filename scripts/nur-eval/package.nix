# nur-eval, wrapped with its eval file and this flake's nixpkgs as the default.
# `nix run .#nur-eval [-- -nixpkgs <path>]` from the repo root; it calls the
# nix-env and nix-instantiate on PATH, as NUR's CI does. The build runs the
# Go tests.
{ pkgs }:
let
  inherit (pkgs) lib;

  unwrapped = pkgs.buildGoModule {
    pname = "nur-eval";
    version = "0.1.0";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.fileFilter (file: lib.hasSuffix ".go" file.name || file.name == "go.mod") ./.;
    };
    vendorHash = null;
    meta.mainProgram = "nur-eval";
  };
in
pkgs.writeShellApplication {
  name = "nur-eval";
  text = ''exec ${lib.getExe unwrapped} -eval ${./eval-repo.nix} -nixpkgs ${pkgs.path} "$@"'';
}
