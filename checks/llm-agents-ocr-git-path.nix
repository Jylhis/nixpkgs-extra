# open-code-review rejects git < 2.41, so the pinned git must come first on
# the ocr wrapper's PATH. With `--suffix` an older system git earlier on the
# caller's PATH would win.
{
  pkgs,
  repo,
  llm-agents,
  ...
}:
let
  inherit (pkgs) lib;
  ocr =
    ((pkgs.extend llm-agents.overlays.shared-nixpkgs).extend repo.overlays.llm-agents)
    .llm-agents.open-code-review;
  hook = ocr.postInstall;
in
if !(lib.hasInfix "--prefix PATH" hook) || lib.hasInfix "--suffix PATH" hook then
  throw "open-code-review must wrap ocr with --prefix PATH (not --suffix), got: ${hook}"
else
  pkgs.runCommand "llm-agents-ocr-git-path" { } "touch $out"
