# nixbuild.net remote builder integration for distributed NixOS builds
{
  lib,
  config,
  ...
}:
let
  cfg = config.services.nixbuild;
in
{
  options.services.nixbuild = {
    enable = lib.mkEnableOption "nixbuild.net remote builder";
    privateKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to the SSH private key for nixbuild.net authentication";
    };
    systems = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      description = "List of system architectures to offload builds for";
    };
    maxJobs = lib.mkOption {
      type = lib.types.int;
      default = 100;
      description = "Maximum number of concurrent build jobs";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ssh.extraConfig = ''
      Host eu.nixbuild.net
        PubkeyAcceptedKeyTypes ssh-ed25519
        ServerAliveInterval 60
        IPQoS throughput
        IdentityFile ${cfg.privateKeyFile}
    '';

    programs.ssh.knownHosts.nixbuild = {
      hostNames = [ "eu.nixbuild.net" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPIQCZc54poJ8vqawd8TraNryQeJnvH1eLpIDgbiqymM";
    };

    nix.distributedBuilds = true;
    nix.settings.builders-use-substitutes = true;

    nix.buildMachines = map (system: {
      hostName = "eu.nixbuild.net";
      inherit system;
      inherit (cfg) maxJobs;
      supportedFeatures = [
        "benchmark"
        "big-parallel"
      ];
    }) cfg.systems;
  };
}
