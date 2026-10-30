{
  description = "Extra Nix packages and NixOS/Home Manager modules on top of nixpkgs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only the Home Manager module tests use it; consumers can follow their own.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Only the llm-agents override checks use it, as the set
    # overlays.llm-agents applies to.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      fenix,
      home-manager,
      llm-agents,
    }:
    let
      inherit (nixpkgs) lib;

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      eachSystem = lib.genAttrs systems;

      pkgsFor = eachSystem (
        system:
        import nixpkgs {
          inherit system;
          # The arize-phoenix packages are Elastic License 2.0 (source
          # available, unfree to nixpkgs), and a few NVIDIA tools here are
          # unfree binaries. Allow that licence and those packages by name
          # only, so any other unfree dependency still fails evaluation here.
          config.allowUnfreePredicate =
            pkg:
            lib.elem (lib.getName pkg) [ "nvidia-cli" ]
            || lib.all (l: (l.shortName or "") == "elastic20") (lib.toList (pkg.meta.license or [ ]));
        }
      );

      # default.nix is the real entry point; the flake only supplies pinned
      # inputs and splits the result per system.
      repoFor = eachSystem (
        system:
        import ./. {
          pkgs = pkgsFor.${system};
          fenix = fenix.packages.${system};
          fenixFor = system: fenix.packages.${system};
        }
      );

      available =
        system: pkg:
        lib.meta.availableOn pkgsFor.${system}.stdenv.hostPlatform pkg && !(pkg.meta.broken or false);
    in
    {
      inherit (repoFor.x86_64-linux)
        lib
        nixosModules
        homeModules
        ;

      inherit (repoFor.x86_64-linux) overlays;

      packages = eachSystem (system: lib.filterAttrs (_: available system) repoFor.${system}.packages);

      checks = eachSystem (
        system:
        import ./checks {
          pkgs = pkgsFor.${system};
          repo = repoFor.${system};
          packages = self.packages.${system};
          inherit home-manager llm-agents;
        }
      );

      formatter = eachSystem (system: pkgsFor.${system}.nixfmt-tree);

      apps = eachSystem (system: {
        update-docs = {
          type = "app";
          program = lib.getExe (
            import ./scripts/update-docs.nix {
              pkgs = pkgsFor.${system};
              repo = repoFor.${system};
            }
          );
        };
      });

      devShells = eachSystem (system: {
        default = pkgsFor.${system}.mkShellNoCC {
          packages = with pkgsFor.${system}; [
            ast-grep
            nix-update
            nixfmt-tree
          ];
        };
      });
    };
}
