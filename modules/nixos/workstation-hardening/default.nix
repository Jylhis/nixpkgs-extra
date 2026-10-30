# Low-cost hardening for single-user workstations: an explicit firewall,
# loopback-only Docker ports, Lynis KRNL-6000 sysctls, unused network
# protocols refused, no core dumps, process accounting and an audit trail.
#
# Everything is off until `security.workstationHardening.enable` is set; each
# feature then has its own toggle, on by default.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.security.workstationHardening;

  acctDir = "/var/log/account";
  accton = "${pkgs.acct}/bin/accton";

  # Point the kernel at a fresh file first, so accounting never stops, then
  # rename it into place (the kernel follows the inode). Keep pacct.1 to
  # pacct.6, the older ones gzipped. On any failure, re-arm accton on
  # pacct so accounting stays on.
  rotateScript = pkgs.writeShellScript "acct-rotate" ''
    set -eu
    cd ${acctDir}
    trap 'test -e pacct || : > pacct; ${accton} ${acctDir}/pacct' ERR
    umask 077
    : > pacct.new
    ${accton} ${acctDir}/pacct.new
    rm -f pacct.6.gz
    for i in 5 4 3 2; do
      if [ -e "pacct.$i.gz" ]; then mv "pacct.$i.gz" "pacct.$((i + 1)).gz"; fi
    done
    if [ -e pacct.1 ]; then ${pkgs.gzip}/bin/gzip -c pacct.1 > pacct.2.gz; fi
    if [ -e pacct ]; then mv pacct pacct.1; fi
    mv pacct.new pacct
  '';

  toggle =
    description:
    lib.mkOption {
      type = lib.types.bool;
      default = true;
      inherit description;
    };
in
{
  options.security.workstationHardening = {
    enable = lib.mkEnableOption "low-cost hardening for single-user workstations";

    firewall = toggle ''
      Assert the host firewall on explicitly, so the deny-inbound policy holds
      regardless of upstream default changes.
    '';

    dockerLoopback = toggle ''
      Make Docker publish `-p` ports on 127.0.0.1 by default. Published ports
      are DNATed through FORWARD and never reach the nixos-fw INPUT chain, so
      the daemon's default bind address is what keeps them off the network.
      `-p 0.0.0.0:X:Y` still opens a port on purpose. No effect while Docker
      is off. Rootless Podman publishes through the user's slirp4netns or
      pasta and is not covered: bind each Podman or oci-containers port to
      127.0.0.1 explicitly.
    '';

    sysctl = toggle ''
      Set the Lynis KRNL-6000 sysctls that cost nothing on a workstation.
      `fs.suid_dumpable` overrides systemd's 50-coredump.conf, since
      60-nixos.conf sorts later.
    '';

    blacklistProtocols = toggle ''
      Refuse the network protocols listed in {option}`protocols`, each a past
      source of kernel CVEs reachable through an unprivileged socket()
      autoload. An `install` line also refuses an explicit modprobe, which a
      blacklist entry does not.
    '';

    protocols = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "dccp"
        "sctp"
        "rds"
        "tipc"
      ];
      description = "Kernel modules refused when {option}`blacklistProtocols` is on.";
    };

    noCoreDumps = toggle ''
      Disable core dumps, which can hold keys and tokens: systemd-coredump
      stores nothing and the hard core limit is zero, so dumps that never
      reach systemd-coredump are stopped too.
    '';

    processAccounting = toggle ''
      Enable BSD process accounting (`lastcomm`, `sa`). logrotate cannot rotate
      the pacct file: it lacks CAP_SYS_PACCT and its syscall filter blocks
      acct(2). A daily `acct-rotate` timer rotates it and re-arms accton on
      the new file.
    '';

    audit = toggle ''
      Enable auditd with rules for identity, kernel-module changes and for
      what a logged-in user runs as root. Nix daemon builds have no login uid,
      so the auid filter keeps them out. The failure mode stays printk: a full
      backlog never panics the machine.
    '';

    auditWatchPaths = lib.mkOption {
      type = lib.types.listOf lib.types.path;
      default = [ ];
      example = [ "/etc/ssh/sshd_config" ];
      description = ''
        Extra paths to watch for writes and attribute changes, each reported
        under the `watch` audit key. Only used when {option}`audit` is on.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.firewall {
        networking.firewall.enable = true;
      })

      (lib.mkIf cfg.dockerLoopback {
        virtualisation.docker.daemon.settings.ip = lib.mkDefault "127.0.0.1";
      })

      (lib.mkIf cfg.sysctl {
        boot.kernel.sysctl = {
          "net.ipv4.ipfrag_time" = lib.mkDefault 3;
          "net.ipv4.ipfrag_high_thresh" = lib.mkDefault 134217728; # 128 MiB
          "kernel.sysrq" = lib.mkDefault 1;
          "fs.protected_fifos" = 2;
          "fs.protected_regular" = 2;
          "fs.suid_dumpable" = 0;
          "dev.tty.ldisc_autoload" = 0;
          "net.ipv4.conf.all.send_redirects" = 0;
          "net.ipv4.conf.default.send_redirects" = 0;
          "net.ipv4.conf.default.accept_redirects" = 0;
          "net.ipv6.conf.all.accept_redirects" = 0;
          "net.ipv6.conf.default.accept_redirects" = 0;
          "net.ipv4.conf.all.log_martians" = 1;
          "net.ipv4.conf.default.log_martians" = 1;
        };
      })

      (lib.mkIf cfg.blacklistProtocols {
        boot.extraModprobeConfig = lib.concatMapStrings (
          m: "install ${m} ${pkgs.coreutils}/bin/false\n"
        ) cfg.protocols;
      })

      (lib.mkIf cfg.noCoreDumps {
        systemd.coredump.settings.Coredump = {
          Storage = lib.mkDefault "none";
          ProcessSizeMax = lib.mkDefault "0";
        };
        security.pam.loginLimits = [
          {
            domain = "*";
            type = "hard";
            item = "core";
            value = "0";
          }
        ];
      })

      (lib.mkIf cfg.processAccounting {
        environment.systemPackages = [ pkgs.acct ];
        systemd.tmpfiles.rules = [
          "d ${acctDir} 0700 root root -"
          "f ${acctDir}/pacct 0600 root root -"
        ];
        systemd.services.acct = {
          description = "Process accounting";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${accton} ${acctDir}/pacct";
            ExecStop = "${accton} off";
            CapabilityBoundingSet = [ "CAP_SYS_PACCT" ];
          };
        };
        systemd.services.acct-rotate = {
          description = "Rotate the process accounting file";
          after = [ "acct.service" ];
          requires = [ "acct.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = rotateScript;
            CapabilityBoundingSet = [ "CAP_SYS_PACCT" ];
          };
        };
        systemd.timers.acct-rotate = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "daily";
            Persistent = true;
          };
        };
      })

      (lib.mkIf cfg.audit {
        security.auditd.enable = true;
        security.audit = {
          enable = true;
          rules = [
            "-w /etc/passwd -p wa -k identity"
            "-w /etc/group -p wa -k identity"
            "-w /etc/shadow -p wa -k identity"
            "-a always,exit -F arch=b64 -S init_module,finit_module,delete_module -k modules"
            "-a always,exit -F arch=b64 -S execve -F euid=0 -F auid>=1000 -F auid!=unset -k root-exec"
          ]
          ++ map (p: "-w ${p} -p wa -k watch") cfg.auditWatchPaths;
        };
      })
    ]
  );
}
