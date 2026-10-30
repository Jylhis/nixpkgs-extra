# Local mail the classic Unix way: Postfix on loopback, mbox mailboxes in
# /var/spool/mail, setgid sendmail(1) for every user, `mail` from GNU
# mailutils. Each account gets <user>@<host>.localhost plus bare
# <user>@localhost: RFC 6761 section 6.3 makes every name under .localhost
# loopback by protocol, so the dotted form means "this machine" and is
# guaranteed to stay out of the public DNS. The dot also satisfies email
# validators that reject single-label domains.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.localMail;
  fqdn = "${config.networking.hostName}.localhost";
in
{
  options.services.localMail = {
    enable = lib.mkEnableOption "local mailboxes (Postfix on loopback, <user>@<host>.localhost)";

    rootAlias = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "alice";
      description = ''
        User receiving root and postmaster mail; null keeps it in
        /var/spool/mail/root.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.postfix = {
      enable = true;
      rootAlias = lib.mkIf (cfg.rootAlias != null) cfg.rootAlias;
      settings.main = {
        # Mail never leaves the machine: the smtpd accepts connections
        # from local processes only, and any recipient outside
        # mydestination bounces instead of being relayed over SMTP.
        inet_interfaces = "loopback-only";
        default_transport = "error:local delivery only";
        relay_transport = "error:local delivery only";
        myhostname = fqdn;
        mydestination = [
          "$myhostname"
          "localhost"
        ];
        # Without the trailing slash (NixOS default) local(8) writes
        # classic mbox files instead of Maildirs.
        mail_spool_directory = "/var/spool/mail";
        # No software name or version in the greeting, and no mailbox probing.
        smtpd_banner = "$myhostname ESMTP";
        disable_vrfy_command = true;
      };
    };

    # GNU mailutils provides the classic `mail` reader for
    # /var/spool/mail/$USER.
    environment.systemPackages = [ pkgs.mailutils ];
  };
}
