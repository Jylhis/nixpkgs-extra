# nixpkgs-extra

Nix packages and NixOS / Home Manager modules that are not in nixpkgs.
x86_64-linux and aarch64-linux.

## Use

With flakes:

```nix
{
  inputs.nixpkgs-extra.url = "github:Jylhis/nixpkgs-extra";

  outputs = { nixpkgs, nixpkgs-extra, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      modules = [
        # every package at the top level of pkgs
        { nixpkgs.overlays = [ nixpkgs-extra.overlays.default ]; }
        nixpkgs-extra.nixosModules.opensnitch-baseline
        { services.opensnitchBaseline.enable = true; }
      ];
    };
  };
}
```

Run a package directly: `nix run github:Jylhis/nixpkgs-extra#<name>`.

Without flakes, `default.nix` takes your nixpkgs:

```nix
let
  extra = import (fetchTarball "https://github.com/Jylhis/nixpkgs-extra/archive/main.tar.gz") {
    inherit pkgs;
  };
in
extra.packages.<name> # also extra.overlays.default, extra.nixosModules, extra.homeModules
```

Modules don't need the overlay: their `package` options default to this
repo's builds. The overlay only adds the packages to `pkgs`.

Option references: [NixOS modules](docs/nixos-options.md),
[Home Manager modules](docs/home-options.md).

## Packages

<!-- BEGIN PACKAGES -->
<!-- END PACKAGES -->

## Overrides

`overlays.overrides` replaces these nixpkgs attributes in place. It is
separate from `overlays.default` and opt-in: everything in your system that
depends on an overridden attribute rebuilds (libsolv and librepo feed dnf5,
micromamba and others), and the binary cache no longer covers it.

```nix
{ nixpkgs.overlays = [ nixpkgs-extra.overlays.overrides ]; }
```

The `llm-agents.*` entries replace packages of
[numtide/llm-agents.nix](https://github.com/numtide/llm-agents.nix) inside
`pkgs.llm-agents`. Apply `overlays.llm-agents` after llm-agents'
`overlays.shared-nixpkgs`; without that set it does nothing.

```nix
{
  nixpkgs.overlays = [
    llm-agents.overlays.shared-nixpkgs
    nixpkgs-extra.overlays.llm-agents
  ];
}
```

<!-- BEGIN OVERRIDES -->
<!-- END OVERRIDES -->

## Contributing

[AGENTS.md](AGENTS.md) covers layout and conventions. Run `nix fmt`,
`nix run .#update-docs` and `nix flake check` before opening a pull request.

## License

MIT, see [LICENSE](LICENSE). Packaged software keeps its own license, listed
in each package's `meta.license`. Files adapted from other projects are
listed in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
