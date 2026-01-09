{ config, pkgs, ... }:

{
  environment.etc."ssh/sshd_config.d/102-use-dns.conf".text = ''
    # Disable DNS lookup to speed up SSH connections
    # This helps when DNS resolution is slow or failing (common in VPN/Tailscale)
    UseDNS no
  '';
}
