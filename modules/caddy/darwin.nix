{ config, pkgs, ... }:

let
  hostName = config.networking.hostName;
  domain = "${hostName}.internal";
in
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

    "caddy/sites/opencloud.caddy".text = ''
      https://opencloud.${domain} {
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
      https://immich.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:2283
      }
    '';

    "caddy/sites/index.caddy".text = ''
      https://${domain} {
        import internal_tls
        handle /index {
          header Content-Type "text/html; charset=utf-8"
          respond `${builtins.readFile ./index.html}` 200
        }
        handle {
          redir / /index
        }
      }
    '';

    "caddy/sites/ca.caddy".text = ''
      http://ca.${domain}, https://ca.${domain} {
        import internal_tls
        handle /ca.crt {
          root * /var/lib/caddy
          @caddy_exists file /caddy/pki/authorities/local/root.der
          rewrite @caddy_exists /caddy/pki/authorities/local/root.der

          header Content-Type "application/x-x509-ca-cert"
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
      # CA cert will be at /var/lib/caddy/caddy/pki/authorities/local/root.crt
      # (macOS: Caddy resolves data dirs relative to HOME via ~/Library/Application Support/Caddy/)
      # HOME must be set so Caddy can resolve OS config/cache directories.
      EnvironmentVariables = {
        CADDY_DATA_DIR = "/var/lib/caddy";
        XDG_DATA_HOME = "/var/lib/caddy";
        HOME = "/var/lib/caddy";
      };
    };
    script = ''
      mkdir -p /var/lib/caddy
      # Ensure Caddy has permissions to write to its data dir (running as root)
      chmod 755 /var/lib/caddy

      # Convert PEM to DER if the cert already exists (covers restarts)
      PEM="/var/lib/caddy/caddy/pki/authorities/local/root.crt"
      DER="/var/lib/caddy/caddy/pki/authorities/local/root.der"
      [ -f "$PEM" ] && ${pkgs.openssl}/bin/openssl x509 -in "$PEM" -outform DER -out "$DER"

      # Background converter for first boot (cert doesn't exist yet)
      (
        for i in $(seq 1 12); do
          [ -f "$PEM" ] && break
          sleep 5
        done
        [ -f "$PEM" ] && [ ! -f "$DER" ] && \
          ${pkgs.openssl}/bin/openssl x509 -in "$PEM" -outform DER -out "$DER"
      ) &

      exec ${pkgs.caddy}/bin/caddy run \
        --config /etc/caddy/Caddyfile \
        --adapter caddyfile
    '';
  };
}
