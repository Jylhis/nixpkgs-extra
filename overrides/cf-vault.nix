# cf-vault 0.0.22 (nixpkgs has 0.0.18); later tags need Go 1.27.
{ final, prev }:
prev.cf-vault.overrideAttrs (_: rec {
  version = "0.0.22";

  src = final.fetchFromGitHub {
    owner = "jacobbednarz";
    repo = "cf-vault";
    tag = "v${version}";
    hash = "sha256-j3MFWiCmXZhLtvc2wJSxZ1p1E0hQHuozvV+3pgVCx9s=";
  };

  vendorHash = "sha256-3UYh776t6fPjTBplCL3pJhjTeICSGJs/YLgdFCXp2AI=";
})
