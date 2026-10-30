# Opt-in: replaces the nixpkgs attributes in ../overrides in place. Unlike
# overlays.default it changes what other nixpkgs packages build against, so
# everything depending on an overridden attribute rebuilds.
final: prev: (import ../overrides { inherit (prev) lib; }).overlay final prev
