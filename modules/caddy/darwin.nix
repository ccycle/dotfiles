{ pkgs, ... }:

{
  environment.etc."caddy/Caddyfile".text = ''
    {
      admin off
    }

    https://nextcloud.mac-mini-m4.internal {
      tls internal
      reverse_proxy 127.0.0.1:8080
    }
  '';

  launchd.daemons.caddy = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/caddy.log";
      StandardErrorPath = "/var/log/caddy.log";
      # Store Caddy data (including the local CA cert) in a predictable location.
      # CA cert will be at /var/lib/caddy/pki/authorities/local/root.crt
      # HOME must be set so Caddy can resolve OS config/cache directories.
      EnvironmentVariables = {
        CADDY_DATA_DIR = "/var/lib/caddy";
        HOME = "/var/lib/caddy";
      };
    };
    script = ''
      mkdir -p /var/lib/caddy
      exec ${pkgs.caddy}/bin/caddy run \
        --config /etc/caddy/Caddyfile \
        --adapter caddyfile
    '';
  };
}
