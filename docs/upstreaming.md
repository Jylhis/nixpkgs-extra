# Upstreaming

Everything here should move to nixpkgs or numtide/llm-agents.nix without a
rewrite. Both projects enforce more than nixfmt and attribute presence, so
this repo checks their rules too. This page lists those rules, where each
comes from and which check enforces it here, then the steps of a
submission.

Sources:

- nixpkgs master (2026-10-24): `CONTRIBUTING.md`, `pkgs/README.md`,
  `pkgs/by-name/README.md`, `nixos/README.md`, `maintainers/README.md`,
  `ci/` and nixpkgs-vet 0.3.5.
- llm-agents.nix at the `llm-agents` input pinned in `flake.lock`:
  `AGENTS.md`, `checks/`, `rules/`, `lib/`, `.github/ci/` and
  `.github/workflows/`.

## Strictness tiers

The universal rules apply to every package. Target-specific rules apply
only to a package that declares `passthru.upstream = [ "nixpkgs" ]`,
`[ "llm-agents" ]` or both; `upstream-targets` checks them. Today only
`openviking` (llm-agents) is tagged. Not tagged, and why:

- `openhands`: llm-agents already ships it as `openhands-agent-canvas`.
- `mem0ai`: a library, and llm-agents requires `meta.mainProgram`.
- `phoenix-mcp`, `ghidra-mcp`: MCP servers belong in
  natsukium/mcp-servers-nix.
- `oryx`: its lockfiles are vendored and refreshed by hand with a fenix
  nightly, so it has no `updateScript`, and nixpkgs would not take the fenix
  toolchain.

## nixpkgs: blocking in CI

| Rule | Source | Checked here by |
|---|---|---|
| New top-level packages live in `pkgs/by-name/<shard>/<name>/package.nix`, where shard is `toLower (substring 0 2 name)` | nixpkgs-vet NPV-162/142 | manual (at submission) |
| Name matches `^[A-Za-z_][A-Za-z0-9_-]*$` | NPV-141 | `meta-style` |
| No paths outside the package directory, and no `<...>`, absolute or `~/` paths | NPV-121..128 | ast-grep `no-path-outside-package` (`../` only) |
| No list literal passed to `lib.optional` | NPV-171 | ast-grep `no-optional-list-literal` |
| New packages must evaluate with `strictDeps = true` and `__structuredAttrs = true` | NPV-164/166 | `upstream-targets`, nixpkgs tier |
| nixfmt formatting | `ci/treefmt.nix` | `format` |
| `nixf-diagnose --auto-fix` is clean (unused `with`/`rec`, redundant parens, URL literals, undefined vars) | `ci/treefmt.nix` | `format` (`scripts/formatter.nix`) |
| keep-sorted blocks | `ci/treefmt.nix` | `format` |
| editorconfig | `ci/treefmt.nix` | not checked; the repo has no `.editorconfig` |
| `nix-instantiate --parse` prints no `warning` | `ci/parse.nix` | `parse` |
| Eval with `checkMeta = true`, `allowAliases = false`: meta value types are validated, unknown meta keys and aliases are rejected | `ci/eval/outpaths.nix`, `pkgs/stdenv/generic/check-meta.nix` | `check-meta` |
| Every option has a `description` and a `type`; a default that reads `pkgs` needs `defaultText` | `nixos/lib/make-options-doc/mergeJSON.py`, `nixos/lib/eval-cacheable-options.nix` | `module-options` |
| A maintainer entry has `name`, `github` and an int `githubId`; email is not `noreply.github.com`; entries are sorted | `lib/tests/maintainer-module.nix`, `maintainer-list.nix` | `maintainers` |
| Commit subject contains `": "`, has no trailing `.`, no `fixup!`/`squash!`/`amend!` prefix and no Conventional Commits prefix; author and committer are set | `ci/github-script/lint-commits.ts` | `lint-commits` (CI `commits` job) |
| Fewer than 500 rebuilds when targeting master, otherwise target `staging` | `ci/github-script/check-target-branch.ts` | manual |

## nixpkgs: enforced in review

| Rule | Source | Checked here by |
|---|---|---|
| `meta.description` is one sentence, capitalised, does not start with A/An/The or the package name, has no trailing punctuation | `pkgs/README.md` "Meta attributes" | `meta-style` |
| `pname` is lowercase and equal to the attribute name | `pkgs/README.md` | `meta-style` (with a reasoned exception list) |
| `version` starts with a digit, or is `<last>-unstable-YYYY-MM-DD` / `0-unstable-YYYY-MM-DD` | `pkgs/README.md` | `meta-style`, ast-grep `version-unstable-format` |
| `meta.mainProgram`, `homepage` and `changelog` are strings | `pkgs/README.md` | `meta-style` |
| `meta.license`, `meta.maintainers` and `meta.platforms` are set; `sourceProvenance` is set for non-source builds | `pkgs/README.md` | `meta-completeness` |
| `finalAttrs` instead of `rec` | `doc/stdenv/stdenv.chapter.md` | ast-grep `prefer-finalattrs` |
| `tag` instead of `rev`, `rev` only for full SHAs, SRI `hash` | `doc/build-helpers/fetchers.chapter.md` | ast-grep `prefer-tag-over-rev`, `no-unpinned-rev`, `no-legacy-sha256` |
| No `with lib;` | `CONTRIBUTING.md` | ast-grep `no-with-lib` |
| `passthru.updateScript` and `meta.changelog` are set | `pkgs/README.md` | `upstream-targets`, nixpkgs tier |
| Patches use `fetchpatch2` with `?full_index=1` and a comment saying why | `pkgs/README.md` "Sources" | manual |
| Commit subjects: `pkg: init at X`, `pkg: X -> Y`, `nixos/<m>: init`; a `maintainers: add <x>` commit comes first and separate | `pkgs/README.md`, `maintainers/README.md` | `lint-commits` warns on an unknown prefix |
| An `Assisted-by:` trailer on AI-assisted commits (`Co-authored-by` does not count) and disclosure in the PR | `CONTRIBUTING.md` "Automation/AI policy" | `lint-commits` checks the format when present |
| Module: options under the right namespace, typed, documented, with defaults and examples; `meta.maintainers`; RFC 42 `settings` via `pkgs.formats`; registered in `module-list.nix`; test in `all-tests.nix` linked from `passthru.tests`; release note under "New Modules" | `nixos/README.md`, `nixos/doc/manual/development/` | `module-options` for docs, the rest manual |
| Acceptance: mature, clearly licensed, not niche, maintained upstream, built from source where possible | `pkgs/README.md` "Quick Start" | manual |

## llm-agents.nix: CI

| Rule | Source | Checked here by |
|---|---|---|
| `meta.changelog`, `meta.mainProgram`, non-empty `meta.sourceProvenance`, `passthru.category` | `checks/meta-completeness.nix` | `meta-completeness`, changelog in the llm-agents tier |
| New packages have at least one maintainer | `.github/ci/check_maintainers.py` | `meta-completeness` |
| Only `bin sbin lib lib64 libexec share include etc opt Applications nix-support` directly under `$out` | `lib/check-package.nix` | `pkgs-<name>` FHS check |
| treefmt clean: nixfmt, deadnix, shfmt, shellcheck, mdformat, ruff, strict mypy on `update.py` | `packages/formatter/treefmt.nix` | nixfmt only; run theirs at submission |
| ast-grep: no legacy `sha256`, prefer `tag`, no unpinned `rev` | `rules/` | ast-grep (copied from llm-agents) |
| ast-grep: no `x86_64-darwin` string | `rules/no-x86-64-darwin.yml` | ast-grep `no-x86-64-darwin` |
| `formatelf` instead of `autoPatchelfHook`; the in-repo `buildNpmPackage` with `npmDepsFetcherVersion = 2` | `rules/use-formatelf.yml`, `rules/use-persystem-buildnpmpackage.yml` | `upstream-targets`, llm-agents tier |
| `passthru.category` is one of their categories | `scripts/generate-package-docs.nu` | `upstream-targets`, llm-agents tier |
| `doInstallCheck` (a version check) | `AGENTS.md` | `upstream-targets`, llm-agents tier |
| README equals the generator output | `.github/workflows/check-readme.yml` | manual |
| Builds on every platform it claims (x86_64-linux, aarch64-linux, aarch64-darwin) | nixbot | manual |

## llm-agents.nix: conventions

- `versionCheckHook` with `doInstallCheck = true`, plus their
  `versionCheckHomeHook` when the tool needs a writable HOME (here:
  nixpkgs' `writableTmpDirAsHomeHook` and `versionCheckKeepEnvironment`).
- Bun-compiled binaries need `dontStrip = true`.
- Darwin codesign hooks are needed when upstream signs its binaries.
- Maintainers go in their `lib/default.nix` as `{ github, githubId, name }`
  and are referenced as `flake.lib.maintainers.<x>`.
- Unfree licences use `flake.lib.licenses.unfree`.
- `nix-update` comes first, then `passthru.updater = mkUpdater { ... }`, then
  a custom typed `update.py`.
- The maintainers package only tools they use themselves; contributors
  maintain what they add.

## Submitting to nixpkgs

1. If you are not yet a nixpkgs maintainer, open with a separate
   `maintainers: add <handle>` commit that copies the entry from
   `lib/maintainers.nix` into `maintainers/maintainer-list.nix`.
2. Move `packages/<name>/package.nix` to
   `pkgs/by-name/<shard>/<name>/package.nix`. Replace arguments only this
   repo's scope provides (other packages here, `fenix`) with nixpkgs
   attributes, and drop `passthru.category` and `passthru.upstream`.
3. Commit as `<name>: init at <version>`, with an
   `Assisted-by: AGENT:MODEL [tools]` trailer if AI helped.
4. Run `nixpkgs-review rev HEAD`, and check the rebuild count to pick
   `master` or `staging`.
5. For a module: move it to `nixos/modules/<category>/<name>.nix`, add it to
   `module-list.nix`, set `meta.maintainers` (NixOS checks it against
   nixpkgs' `lib.maintainers`, so it can only be set once the maintainer
   entry exists), move `vm-test.nix` to `nixos/tests/` and register it in
   `all-tests.nix` and the package's `passthru.tests`, add a release note
   under "New Modules", and commit as `nixos/<name>: init`.
6. Fill in the PR template, including the AI disclosure.

## Submitting to llm-agents.nix

1. Add yourself to their `lib/default.nix` if needed, and refer to it as
   `flake.lib.maintainers.<handle>`.
2. Copy the package to `packages/<name>/package.nix`. Switch to their scope
   helpers: their `buildNpmPackage`, `formatelf` instead of
   `autoPatchelfHook`, `versionCheckHomeHook`.
3. Regenerate their README with `./scripts/generate-package-docs.nu`.
4. Run their `nix fmt` (treefmt with deadnix, shellcheck and mdformat).
5. Commit as `<name>: init at <version>` and fill in their PR template.

<!-- Assisted-by: Claude Code:claude-opus-5-5 -->
