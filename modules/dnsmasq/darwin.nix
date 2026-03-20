{ config, pkgs, tailscalePackage, ... }:

let
  domain = "${config.networking.hostName}.internal";
in
{
  # To register this as the authoritative DNS for *.${domain}
  # across the tailnet, configure Split DNS in the Tailscale admin console:
  #   https://login.tailscale.com/admin/dns
  #   → Add nameserver → Custom → IP: <tailscale-ip>, Domain: ${domain}
  #   → Enable "Restrict to domain" (Split DNS)
  #
  # The Tailscale IP is resolved dynamically at daemon startup via `tailscale ip -4`,
  # so no hardcoding is required.
  launchd.daemons.dnsmasq = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/dnsmasq.log";
      StandardErrorPath = "/var/log/dnsmasq.log";
    };
    script = ''
      # Wait for Tailscale to be ready
      until TAILSCALE_IP=$(${tailscalePackage}/bin/tailscale ip -4 2>/dev/null) && [ -n "$TAILSCALE_IP" ]; do
        echo "Waiting for Tailscale..."
        sleep 2
      done
      echo "Tailscale IP: $TAILSCALE_IP"

      exec ${pkgs.dnsmasq}/bin/dnsmasq \
        --address=/.${domain}/"$TAILSCALE_IP" \
        --listen-address="$TAILSCALE_IP" \
        --bind-interfaces \
        --port=53 \
        --no-daemon
    '';
  };
}
