{ config, lib, pkgs, tailscalePackage, ... }:

with lib;

let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale.splitDns = {
    enable = mkEnableOption "Tailscale Split DNS auto-registration";
  };

  config = mkIf cfg.splitDns.enable {
    environment.etc."newsyslog.d/tailscale-split-dns.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/tailscale-split-dns.log      644   7      10240 *     GZ
    '';

    sops.secrets.tailscale_api_key = {
      sopsFile = ./secrets.yaml;
    };

    sops.secrets.tailscale_tailnet = {
      sopsFile = ./secrets.yaml;
    };

    launchd.daemons.tailscale-split-dns = {
      serviceConfig = {
        RunAtLoad = true;
        KeepAlive = false;
        StandardOutPath = "/var/log/tailscale-split-dns.log";
        StandardErrorPath = "/var/log/tailscale-split-dns.log";
      };
      script = ''
        until TAILSCALE_IP=$(${tailscalePackage}/bin/tailscale ip -4 2>/dev/null) && [ -n "$TAILSCALE_IP" ]; do
          echo "Waiting for Tailscale..."
          sleep 2
        done

        DOMAIN="${config.networking.hostName}.internal"
        API_KEY=$(cat ${config.sops.secrets.tailscale_api_key.path})
        TAILNET=$(cat ${config.sops.secrets.tailscale_tailnet.path})

        echo "Registering Split DNS: $DOMAIN -> $TAILSCALE_IP"

        MAX_RETRIES=5
        RETRY_DELAY=5
        for i in $(seq 1 $MAX_RETRIES); do
          if ${pkgs.curl}/bin/curl -sf -X PUT \
            "https://api.tailscale.com/api/v2/tailnet/$TAILNET/dns/splitdns/$DOMAIN" \
            -u "$API_KEY:" \
            -H "Content-Type: application/json" \
            -d "[\"$TAILSCALE_IP\"]"; then
            echo "Split DNS registered: $DOMAIN -> $TAILSCALE_IP"
            exit 0
          fi
          echo "Split DNS registration failed (attempt $i/$MAX_RETRIES), retrying in ''${RETRY_DELAY}s..."
          sleep $RETRY_DELAY
          RETRY_DELAY=$((RETRY_DELAY * 2))
        done
        echo "ERROR: Split DNS registration failed after $MAX_RETRIES attempts"
        exit 1
      '';
    };
  };
}
