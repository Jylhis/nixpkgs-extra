# `nix run .#update-docs`: rewrite the generated docs in the working tree.
{ pkgs, repo }:
let
  docs = import ./docs.nix { inherit pkgs repo; };
in
pkgs.writeShellApplication {
  name = "update-docs";
  runtimeInputs = [ pkgs.gawk ];
  text = ''
    install -m 644 ${docs.nixosOptions} docs/nixos-options.md
    install -m 644 ${docs.homeOptions} docs/home-options.md
    # Replace everything between the README markers with the generated lists.
    awk -v packages=${docs.packageList} -v overrides=${docs.overrideList} '
      /<!-- BEGIN PACKAGES -->/ { print; while ((getline line < packages) > 0) print line; skip = 1; next }
      /<!-- BEGIN OVERRIDES -->/ { print; while ((getline line < overrides) > 0) print line; skip = 1; next }
      /<!-- END (PACKAGES|OVERRIDES) -->/ { skip = 0 }
      !skip
    ' README.md > README.md.new
    mv README.md.new README.md
  '';
}
