{ pkgs, ... }:

{
  environment.etc = {
    "caddy/Caddyfile".text = ''
      {
        admin off
      }

      # Common snippets
      (internal_tls) {
        tls internal
      }

      import /etc/caddy/sites/*.caddy
    '';

    "caddy/sites/nextcloud.caddy".text = ''
      https://nextcloud.mac-mini-m4.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:8080
      }
    '';

    "caddy/sites/opencloud.caddy".text = ''
      https://opencloud.mac-mini-m4.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:9200 {
          flush_interval -1
          transport http {
            response_header_timeout 120s
          }
        }
      }
    '';

    "caddy/sites/immich.caddy".text = ''
      https://immich.mac-mini-m4.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:2283
      }
    '';

    "caddy/sites/ca.caddy".text = ''
      http://ca.mac-mini-m4.internal, https://ca.mac-mini-m4.internal {
        import internal_tls
        handle /ca.crt {
          root * "/var/lib/caddy/Library/Application Support/Caddy/pki/authorities/local"
          rewrite * /root.crt
          header Content-Type "application/x-x509-ca-cert"
          header Content-Disposition "attachment; filename=ca.crt"
          file_server
        }
        handle {
          header Content-Type "text/html; charset=utf-8"
          respond `${builtins.readFile ./ca.html}` 200
        }
      }
    '';
  };

  launchd.daemons.caddy = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/caddy.log";
      StandardErrorPath = "/var/log/caddy.log";
      # Store Caddy data (including the local CA cert) in a predictable location.
      # CA cert will be at /var/lib/caddy/Library/Application Support/Caddy/pki/authorities/local/root.crt
      # (macOS: Caddy resolves data dirs relative to HOME via ~/Library/Application Support/Caddy/)
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
