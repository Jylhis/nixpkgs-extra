# Every llm-agents-overrides/<attr>.nix: a numtide/llm-agents.nix package
# replaced in place in pkgs.llm-agents by overlays.llm-agents. Same file
# format as overrides/: `{ final, prev }: <derivation>` built on
# `prev.llm-agents.<attr>`, first line a `# ` description.
{ lib }:
import ../overrides {
  inherit lib;
  dir = ./.;
}
