{ pkgs, ... }:

{
  # Replace 100.x.x.x with the actual Tailscale IP of this Mac Mini.
  # You can find it with: tailscale ip -4
  #
  # To register this as the authoritative DNS for *.mac-mini-m4.internal
  # across the tailnet, configure Split DNS in the Tailscale admin console:
  #   https://login.tailscale.com/admin/dns
  #   → Add nameserver → Custom → IP: <tailscale-ip>, Domain: mac-mini-m4.internal
  #   → Enable "Restrict to domain" (Split DNS)
  environment.etc."dnsmasq.conf".text = ''
    # Resolve all *.mac-mini-m4.internal to this machine's Tailscale IP.
    # Replace 100.x.x.x with the actual Tailscale IP (tailscale ip -4).
    address=/.mac-mini-m4.internal/100.x.x.x

    # Bind only to the Tailscale interface (not exposed to the public internet)
    listen-address=100.x.x.x
    bind-interfaces
    port=53
  '';

  launchd.daemons.dnsmasq = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/dnsmasq.log";
      StandardErrorPath = "/var/log/dnsmasq.log";
    };
    script = ''
      exec ${pkgs.dnsmasq}/bin/dnsmasq \
        --conf-file=/etc/dnsmasq.conf \
        --no-daemon
    '';
  };
}
