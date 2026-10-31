# Stricter rules for packages meant to move upstream. A package opts in with
# `passthru.upstream = [ "nixpkgs" ]`, `[ "llm-agents" ]` or both, and must
# then meet what that project's CI and review ask for (docs/upstreaming.md);
# everything else only needs the universal checks.
{ pkgs, repo, ... }:
let
  inherit (pkgs) lib;

  targets = [
    "nixpkgs"
    "llm-agents"
  ];

  # CATEGORY_ORDER in numtide/llm-agents.nix scripts/generate-package-docs.nu,
  # without its "Uncategorized" fallback.
  llmAgentsCategories = [
    "AI Coding Agents"
    "AI Assistants"
    "Claude Code Ecosystem"
    "ACP Ecosystem"
    "Usage Analytics"
    "Workflow & Project Management"
    "Code Review"
    "Voice & Transcription"
    "Memory & Code Intelligence"
    "Sandboxing & Isolation"
    "Skills & Plugins"
    "Utilities"
  ];

  nixpkgsProblems =
    pkg:
    lib.optional (!(pkg.strictDeps or false)) "strictDeps is not true"
    ++ lib.optional (!(pkg.__structuredAttrs or false)) "__structuredAttrs is not true"
    ++ lib.optional (!(pkg.meta ? changelog)) "meta.changelog is not set"
    ++ lib.optional (!(pkg.passthru ? updateScript)) "passthru.updateScript is not set"
    ++ lib.optional ((pkg.meta.platforms or [ ]) == [ ]) "meta.platforms is empty";

  llmAgentsProblems =
    pkg:
    let
      category = pkg.passthru.category or null;
    in
    lib.optional (!(pkg.meta ? changelog)) "meta.changelog is not set"
    ++ lib.optional (
      !lib.elem category llmAgentsCategories
    ) "passthru.category ${toString category} is not an llm-agents category"
    ++ lib.optional (
      pkg ? npmDeps && (pkg.env.NIX_NPM_FETCHER_VERSION or 1) != 2
    ) "npmDepsFetcherVersion is not 2"
    ++ lib.optional (lib.any (dep: lib.getName dep == "auto-patchelf-hook") (
      pkg.nativeBuildInputs or [ ]
    )) "uses autoPatchelfHook, llm-agents wants formatelf"
    ++ lib.optional (!(pkg.doInstallCheck or false)) "doInstallCheck is not true";

  checkPackage =
    name: pkg:
    let
      upstream = pkg.passthru.upstream or [ ];
      unknown = lib.subtractLists targets upstream;
      problems =
        lib.optional (unknown != [ ]) "unknown passthru.upstream ${lib.concatStringsSep ", " unknown}"
        ++ lib.optionals (lib.elem "nixpkgs" upstream) (map (p: "nixpkgs: ${p}") (nixpkgsProblems pkg))
        ++ lib.optionals (lib.elem "llm-agents" upstream) (
          map (p: "llm-agents: ${p}") (llmAgentsProblems pkg)
        );
    in
    map (problem: "${name}: ${problem}") problems;

  problems = lib.concatLists (lib.mapAttrsToList checkPackage repo.packages);
in
if problems != [ ] then
  throw ("Upstream target rules:\n" + lib.concatStringsSep "\n" problems)
else
  pkgs.runCommand "upstream-targets" { } "touch $out"
