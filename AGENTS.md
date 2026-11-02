# Repository guidelines

nixpkgs-extra is a set of Nix packages and NixOS / Home Manager modules that
are not (yet) in nixpkgs. Everything here is meant to be generic: usable on
any machine, upstreamable to nixpkgs without a rewrite.
[docs/upstreaming.md](docs/upstreaming.md) lists the upstream rules, the
check that enforces each one here, and the submission steps.

## Layout

- `default.nix`: the real entry point. `import ./. { pkgs = ...; }` returns
  `{ lib, packages, scope, overrides, nixosModules, homeModules, overlays }`. Without
  arguments it uses the nixpkgs revision in `flake.lock`.
- `flake.nix`: wraps `default.nix` per system and adds `checks`, `formatter`,
  `apps.update-docs` and a dev shell.
- `packages/<name>/package.nix`: one directory per package, auto-discovered.
  Every package is called from one scope (`packages/default.nix`) that holds
  all of them plus a `lib` whose `maintainers` include ours, so a
  package asks for another one by naming it as an argument.
- `modules/nixos/<name>/default.nix`, `modules/home/<name>/default.nix`:
  auto-discovered and exported as `nixosModules.<name>` / `homeModules.<name>`
  (plus `default`, importing all). Modules receive `extraPkgs` (this repo's
  packages built against the module's `pkgs`) and `extraLib`.
- `modules/<kind>/<name>/test.nix`: eval test, exported as the
  `<kind>-<name>` check. `modules/nixos/<name>/vm-test.nix`: VM test
  (`vm-<name>`), run on x86_64-linux only.
- `overlays/default.nix`: adds every public package at the top level of pkgs.
- `overrides/<attr>.nix`: a nixpkgs attribute changed in place, applied by
  the opt-in `overlays/overrides.nix` (see Overrides).
- `llm-agents-overrides/<attr>.nix`: a numtide/llm-agents.nix package
  changed in place in `pkgs.llm-agents`, applied by the opt-in
  `overlays/llm-agents.nix` (see Overrides).
- `lib/`: helpers shared by modules, exported as `lib`.
- `checks/`: repo-wide checks; `checks/lib.nix` has the test helpers.
- `rules/`: ast-grep rules (`sgconfig.yml`).
- `scripts/docs.nix`: generated docs (README package list,
  `docs/{nixos,home}-options.md`).

## Commands

- Enter the dev shell: `nix develop`.
- Build a package: `nix build .#<name>`.
- Run all checks: `nix flake check`.
- Format: `nix fmt`.
- Regenerate docs after changing packages or options: `nix run .#update-docs`.
- Lint commit messages: `nix run .#lint-commits -- main`.
- Update a package: `nix run nixpkgs#nix-update -- --flake <name>`.

## Naming

Packages land at the top level of pkgs through the overlay, so a package
name must not exist in nixpkgs (`no-nixpkgs-clash` check). On a clash,
rename ours, usually after the upstream binary or project
(`lemonade` became `lemonade-server`).

Helpers that would shadow or duplicate a nixpkgs attribute go in the
`internal` list in `packages/default.nix`: they stay in the scope for other
packages and are never exported.

## Overrides

`overrides/<attr>.nix` changes a nixpkgs package for everyone who applies
`overlays.overrides`: extra build features, outputs or completions that
nixpkgs does not enable. Use it only when the change is meant for every
consumer of that attribute. A variant that only one package here needs is
an `internal` scope package instead (`libwebsockets_4_5` for
lemonade-server).

- The file is `{ final, prev }: <derivation>`, built with `overrideAttrs`
  (or `overridePythonAttrs`) on `prev.<attr>`. Its first line, a `# `
  comment, is the README description.
- Add to nixpkgs' behaviour; don't remove features it enables.
- `overlays.overrides` stays separate from `overlays.default`: it rebuilds
  everything depending on the attribute.
- `override-<attr>` builds it, and is skipped while nixpkgs' own attribute
  fails to evaluate (marked broken upstream); `overrides-target-exists`
  fails once nixpkgs drops or renames the attribute.

`llm-agents-overrides/<attr>.nix` does the same for a package of
numtide/llm-agents.nix, built on `prev.llm-agents.<attr>`, in the same file
format and loaded by the same code (`overrides/default.nix`).

- `overlays.llm-agents` goes after llm-agents' `overlays.shared-nixpkgs`
  and is a no-op without it. It replaces the attribute in the set only:
  other llm-agents packages keep the original.
- The version and hashes stay upstream's, so there is no update script;
  bumping the `llm-agents` flake input moves them.
- The `llm-agents` flake input is for checks only.
  `llm-agents-override-<attr>` builds the override and
  `llm-agents-target-exists` fails once llm-agents drops the package.

## Package metadata

`meta-completeness` requires on every public package:

```nix
passthru.category = "Developer tools";
meta = {
  description = "...";
  homepage = "https://...";
  changelog = "https://.../releases/tag/v${version}"; # when upstream has one
  license = lib.licenses.mit;
  sourceProvenance = [ lib.sourceTypes.fromSource ];
  maintainers = with lib.maintainers; [ jylhis ];
  mainProgram = "name"; # omit only with passthru.library = true
  platforms = lib.platforms.linux;
};
```

A package meant to move upstream sets `passthru.upstream = [ "nixpkgs" ]`,
`[ "llm-agents" ]` or both. `upstream-targets` then holds it to that
project's rules: for nixpkgs `strictDeps`, `__structuredAttrs`,
`meta.changelog`, `passthru.updateScript` and non-empty `meta.platforms`; for
llm-agents `meta.changelog`, one of their categories as `passthru.category`,
npm fetcher version 2, no `autoPatchelfHook` and `doInstallCheck`.

Add new maintainers to `lib/maintainers.nix` in nixpkgs'
`maintainer-list.nix` format.

## Sources and updates

- Keep `version` and hashes inline in `package.nix`, so `nix-update` can bump
  them. Set `passthru.updateScript = nix-update-script { };` (with extra
  arguments when needed); the update workflow picks up every package that
  has one.
- Pin tags with `tag = "v${version}"`, not `rev`; commit hashes stay in
  `rev`. Never pin a branch. Use SRI `hash`, not `sha256`. ast-grep enforces
  all three.
- A package that reads a lockfile it can't get from upstream keeps it next
  to `package.nix`, with an `osv-scanner.toml` for reviewed advisories.

## Output layout

Only these may sit directly under `$out`:
`bin sbin lib lib64 libexec share include etc opt nix-support`.
Anything else collides in `buildEnv` / Home Manager profiles. Put app trees
under `$out/share/<pname>` or `$out/libexec/<pname>`.

## Generic by default

- Module options live under `services.*`, `programs.*` or `security.*`,
  default to off, and take machine-specific values (hosts, credentials,
  paths) as options. Credentials are read from `*File` options at run time,
  never put in the store.
- `package` options default to `extraPkgs.<name>` with
  `defaultText = lib.literalExpression "pkgs.<name>"`.
- Integration with a module this repo does not ship is guarded with
  `options.services ? <name>`, so evaluation never needs it.
- Nothing in the tree refers to one particular machine: no home paths,
  host or tailnet names, or secret-store wiring.

## Tests

Every module ships a `test.nix` built on `checks/lib.nix` (`evalNixos`,
`evalHome`, `expect`, `allOf`, `noFailedAssertions`, `runCases`). Use a
`vm-test.nix` (`pkgs.testers.runNixOSTest`) only when the behaviour can't be
seen from the evaluated config.

## Commits

Small, imperative subject (`oryx: 0.8.0 -> 0.9.0`, `opensnitch-baseline: ...`),
body says why. Run `nix fmt` and `nix flake check` first.
`nix run .#lint-commits -- main` checks subjects against nixpkgs' rules: no
Conventional Commits prefixes, so `docs:` only for a change under `docs/`.
