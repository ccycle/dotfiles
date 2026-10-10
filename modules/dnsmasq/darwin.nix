{
  config,
  lib,
  pkgs,
  tailscalePackage,
  ...
}:

let
  domain = "${config.networking.hostName}.internal";
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkIf config.custom.dnsmasq.enable {
    # Split DNS registration for *.${domain} is automated via
    # the tailscale-split-dns launchd daemon (see modules/tailscale/options.nix).
    # The Tailscale IP is resolved dynamically at daemon startup via `tailscale ip -4`.
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
  };
}
