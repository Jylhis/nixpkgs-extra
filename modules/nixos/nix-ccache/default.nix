# nixpkgs' programs.ccache points its setgid nix-ccache wrapper at a Perl
# script, which the wrapper integrity check rejects (it wants ELF targets).
# This module swaps in an ELF shim. The main programs.ccache option remains
# unchanged; this module only affects the wrapper when both are enabled.
{
  config,
  lib,
  extraPkgs,
  ...
}:
let
  cfg = config.programs.nix-ccache;
in
{
  options.programs.nix-ccache = {
    enable = lib.mkEnableOption "the nix-ccache ELF shim for sandboxed Nix builds";

    package = lib.mkOption {
      type = lib.types.package;
      default = extraPkgs.nix-ccache.override { cacheDir = config.programs.ccache.cacheDir; };
      defaultText = lib.literalExpression "pkgs.nix-ccache.override { cacheDir = config.programs.ccache.cacheDir; }";
      description = ''
        The nix-ccache shim to install. It has its cache directory compiled
        in, so the default follows `programs.ccache.cacheDir`; a custom
        package must be built with the same directory.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ccache.enable = true;
    security.wrappers.nix-ccache.source = lib.mkForce (lib.getExe cfg.package);
  };
}
