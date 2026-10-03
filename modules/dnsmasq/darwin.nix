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

    # dnsmasq has been observed alive but not draining its UDP socket
    # (Recv-Q full, 0% CPU), which KeepAlive cannot detect. Probe it from
    # outside and restart on failure. Before restarting, capture a stack
    # sample (needs root, which this daemon has) to find the root cause.
    launchd.daemons.dnsmasq-healthcheck = {
      serviceConfig = {
        StartInterval = 60;
        StandardOutPath = "/var/log/dnsmasq-healthcheck.log";
        StandardErrorPath = "/var/log/dnsmasq-healthcheck.log";
      };
      script = ''
        # Not ready yet: dnsmasq's own startup loop is still waiting for Tailscale.
        TAILSCALE_IP=$(${tailscalePackage}/bin/tailscale ip -4 2>/dev/null) || exit 0
        PID=$(/usr/bin/pgrep -x dnsmasq) || exit 0

        if ${pkgs.dnsutils}/bin/dig +time=2 +tries=3 +short @"$TAILSCALE_IP" ${domain} A | grep -q .; then
          exit 0
        fi

        echo "$(date '+%F %T') dnsmasq (pid $PID) not answering on $TAILSCALE_IP:53, restarting"
        /usr/sbin/netstat -anv -p udp | grep "$TAILSCALE_IP.53 "
        /usr/bin/sample "$PID" 3 -file /var/log/dnsmasq-stuck-sample.txt >/dev/null 2>&1
        /bin/launchctl kickstart -k system/org.nixos.dnsmasq
      '';
    };

    environment.etc."newsyslog.d/dnsmasq-healthcheck.conf".text = ''
      # logfilename                      [owner:group]  mode  count  size  when  flags
      /var/log/dnsmasq-healthcheck.log   644   7      1024  *     GZ
    '';
  };
}
