{ config, pkgs, username, ... }:

{
  environment.etc."ssh/sshd_config.d/102-use-dns.conf".text = ''
    # Disable DNS lookup to speed up SSH connections
    # This helps when DNS resolution is slow or failing (common in VPN/Tailscale)
    UseDNS no
  '';

  # Alternative SSHD on port 2222
  launchd.daemons.sshd-alt = {
    serviceConfig = {
      Label = "com.local.sshd-alt";
      ProgramArguments = [ "/usr/sbin/sshd" "-D" "-p" "2222" ];
      KeepAlive = true;
      RunAtLoad = true;
    };
  };
}
