# overrides-target-exists for llm-agents-overrides/: every file must replace
# a package numtide/llm-agents.nix still has, so an upstream rename fails
# here instead of silently adding a new package to pkgs.llm-agents. Also
# checks that overlays.llm-agents leaves a pkgs without llm-agents alone.
{
  pkgs,
  repo,
  llm-agents,
  ...
}:
let
  inherit (pkgs) lib;
  upstream = (pkgs.extend llm-agents.overlays.shared-nixpkgs).llm-agents;
  missing =
    lib.filter (name: !(upstream ? ${name}))
      (import ../llm-agents-overrides { inherit lib; }).names;
in
if missing != [ ] then
  throw "llm-agents-overrides/ names packages llm-agents no longer has: ${lib.concatStringsSep ", " missing}"
else if repo.overlays.llm-agents pkgs pkgs != { } then
  throw "overlays.llm-agents must not change a pkgs without llm-agents"
else
  pkgs.runCommand "llm-agents-target-exists" { } "touch $out"
