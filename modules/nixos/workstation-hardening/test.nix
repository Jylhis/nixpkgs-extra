{
  lib,
  module,
  testLib,
  ...
}:
let
  inherit (testLib)
    evalNixos
    expect
    allOf
    noFailedAssertions
    runCases
    ;

  off = evalNixos [ module ];
  on = evalNixos [
    module
    {
      security.workstationHardening = {
        enable = true;
        auditWatchPaths = [ "/etc/ssh/sshd_config" ];
      };
    }
  ];
  partial = evalNixos [
    module
    {
      security.workstationHardening = {
        enable = true;
        audit = false;
        processAccounting = false;
        sysctl = false;
      };
    }
  ];
in
runCases "nixos-workstation-hardening" {
  inert-by-default = allOf [
    (expect (!off.security.auditd.enable) "auditd enabled without the option")
    (expect (!off.systemd.services ? acct) "acct service present without the option")
    (expect (!(off.boot.kernel.sysctl ? "fs.protected_fifos")) "sysctl set without the option")
    (expect (
      !(lib.hasInfix "sctp" off.boot.extraModprobeConfig)
    ) "protocols refused without the option")
  ];
  everything-on-when-enabled = allOf [
    (expect on.networking.firewall.enable "firewall off")
    (expect (on.virtualisation.docker.daemon.settings.ip == "127.0.0.1") "docker not on loopback")
    (expect (on.boot.kernel.sysctl."fs.suid_dumpable" == 0) "suid_dumpable not 0")
    (expect (lib.hasInfix "install sctp" on.boot.extraModprobeConfig) "sctp not refused")
    (expect (on.systemd.coredump.settings.Coredump.Storage == "none") "coredump storage not none")
    (expect (
      on.systemd.services ? acct && on.systemd.timers ? acct-rotate
    ) "process accounting missing")
    (expect on.security.auditd.enable "auditd off")
    (noFailedAssertions on)
  ];
  audit-rules = allOf [
    (expect (builtins.elem "-w /etc/shadow -p wa -k identity" on.security.audit.rules) "identity rule missing")
    (expect (builtins.elem "-w /etc/ssh/sshd_config -p wa -k watch" on.security.audit.rules) "auditWatchPaths rule missing")
    (expect (!(lib.any (lib.hasInfix "sops") on.security.audit.rules)) "secret-store rule present")
  ];
  toggles-switch-features-off = allOf [
    (expect (!partial.security.auditd.enable) "audit toggle ignored")
    (expect (!partial.systemd.services ? acct) "processAccounting toggle ignored")
    (expect (!(partial.boot.kernel.sysctl ? "fs.protected_fifos")) "sysctl toggle ignored")
    (expect partial.networking.firewall.enable "firewall should stay on")
  ];
}
