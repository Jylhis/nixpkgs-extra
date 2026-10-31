# Module option docs as strict as the NixOS manual build: every option has a
# description and a type, and no documented default reads a package (those
# need a defaultText). See optionsDoc in scripts/docs.nix.
{ pkgs, repo, ... }:
let
  docs = import ../scripts/docs.nix { inherit pkgs repo; };
in
pkgs.linkFarm "module-options" {
  nixos = docs.strictOptions.nixos.optionsJSON;
  home = docs.strictOptions.home.optionsJSON;
}
