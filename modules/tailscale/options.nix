{ config, lib, pkgs, tailscalePackage, ... }:

with lib;

let
  cfg = config.services.tailscale;
in
{
  options.services.tailscale.splitDns = {
    enable = mkEnableOption "Tailscale Split DNS auto-registration";

    tailnet = mkOption {
      type = types.str;
      description = "Tailnet name (org name or email domain).";
    };
  };

  config = mkIf cfg.splitDns.enable {
    environment.etc."newsyslog.d/tailscale-split-dns.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/tailscale-split-dns.log      644   7      10240 *     GZ
    '';

    sops.secrets.tailscale_api_key = {
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

        echo "Registering Split DNS: $DOMAIN -> $TAILSCALE_IP"

        ${pkgs.curl}/bin/curl -sf -X PUT \
          "https://api.tailscale.com/api/v2/tailnet/${cfg.splitDns.tailnet}/dns/splitdns/$DOMAIN" \
          -u "$API_KEY:" \
          -H "Content-Type: application/json" \
          -d "[\"$TAILSCALE_IP\"]"

        echo "Split DNS registered: $DOMAIN -> $TAILSCALE_IP"
      '';
    };
  };
}
