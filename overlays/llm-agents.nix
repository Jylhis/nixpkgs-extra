# Opt-in: replaces the packages in ../llm-agents-overrides inside
# pkgs.llm-agents. Apply it after numtide/llm-agents.nix's
# overlays.shared-nixpkgs, which creates that set; without it this overlay
# changes nothing. Other llm-agents packages keep building against the
# original attributes, since the set is replaced from outside its scope.
final: prev:
prev.lib.optionalAttrs (prev ? llm-agents) {
  llm-agents =
    prev.llm-agents // (import ../llm-agents-overrides { inherit (prev) lib; }).overlay final prev;
}
