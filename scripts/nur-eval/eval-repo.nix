# What NUR's lib/evalRepo.nix does with a repository: call nur.nix with only
# `pkgs`, refusing an argument that has no default. With namesOnly, return the
# names of the top-level derivations instead, which nix-env must list.
{
  repo,
  namesOnly ? false,
}:
let
  pkgs = import <nixpkgs> { };
  expr = import (repo + "/nur.nix");
  args = builtins.functionArgs expr;
  undefaulted = builtins.filter (arg: arg != "pkgs" && !args.${arg}) (builtins.attrNames args);
  result =
    if undefaulted != [ ] then
      throw "nur.nix: NUR passes only pkgs, but these arguments have no default: ${toString undefaulted}"
    else
      expr (builtins.intersectAttrs args { inherit pkgs; });
in
if namesOnly then
  builtins.filter (name: (result.${name}.type or null) == "derivation") (builtins.attrNames result)
else
  result
