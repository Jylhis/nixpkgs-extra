# U2F hardware key as an ALTERNATIVE to the password on a narrow set of PAM
# services. `control = "sufficient"` means a touch alone authenticates: a
# convenience, not a second factor. Anyone with physical access to an attached
# key can unlock a covered service, which is why the list stays narrow.
#
# Enrollment (per user) arms the touch path:
#   mkdir -p ~/.config/Yubico
#   nix shell nixpkgs#pam_u2f -c pamu2fcfg > ~/.config/Yubico/u2f_keys
# Until then pam_u2f fails and, being "sufficient", is ignored.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.security.u2fKey;
in
{
  options.security.u2fKey = {
    enable = lib.mkEnableOption "U2F hardware key as an alternative authentication factor";

    services = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "sudo"
        "hyprlock"
        "swaylock"
        "polkit-1"
      ];
      description = ''
        PAM services where a U2F touch is accepted in place of the password.
        Excludes greetd, login and sshd: under "sufficient" a touch alone
        would open a fresh session or a remote login.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # security.pam.u2f.enable stays unset: it defaults `u2f.enable` on for EVERY
    # PAM service (sshd, login, greetd). `control` and `settings` apply
    # regardless, so opting in per service is the safe form.
    security.pam.u2f = {
      control = "sufficient";
      # No `nouserok`: with "sufficient" it turns a missing authfile into
      # SUCCESS, so e.g. hyprlock would unlock on a bare Enter.
      settings.cue = true;
    };

    security.pam.services = lib.genAttrs cfg.services (_: {
      u2f.enable = true;
    });

    # Not pulled in without security.pam.u2f.enable; needed for pamu2fcfg.
    environment.systemPackages = [ pkgs.pam_u2f ];
  };
}
