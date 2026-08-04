{ config, lib, pkgs, tailscalePackage, ... }:

let
  hostName = config.networking.hostName;
  domain = "${hostName}.internal";

  caHtml = builtins.replaceStrings [ "__DOMAIN__" "__HOSTNAME__" ] [ domain hostName ]
    (builtins.readFile ./ca.html);

  sortedEntries = lib.sort (a: b: a.name < b.name) config.services.caddy.portalEntries;

  portalCardsHtml = lib.concatMapStringsSep "\n"
    (entry: ''
      <a href="${entry.url}" class="card">
        <div class="logo">${entry.logoSvg}</div>
        <div class="card-body">
          <h2>${entry.name}</h2>
          <p data-lang="ja">${entry.descriptionJa}</p>
          <p data-lang="en" hidden>${entry.descriptionEn}</p>
        </div>
      </a>
    '')
    sortedEntries;

  indexHtml = builtins.replaceStrings
    [ "@domain@" "@hostName@" "@portalCards@" ]
    [ domain hostName portalCardsHtml ]
    (builtins.readFile ./index.html);

  # Hash all Caddy etc entries so the launchd plist changes (and nix-darwin
  # restarts the daemon) whenever any site config is added, removed, or modified.
  caddyEtcHash = builtins.hashString "sha256" (lib.concatStrings
    (lib.mapAttrsToList (_: v: v.text or "")
      (lib.filterAttrs (n: _: lib.hasPrefix "caddy/" n) config.environment.etc)));
in
{
  imports = [
    ./options.nix
  ];

  config = lib.mkIf config.services.caddy.enable {
    services.caddy.portalEntries = [
      {
        name = "CA Certificate";
        url = "https://ca.${domain}";
        descriptionJa = "ルート証明書のダウンロード";
        descriptionEn = "Download Root Certificate";
        logoSvg = builtins.readFile ./ca-certificate-logo.svg;
      }
    ] ++ lib.optionals config.services.atticd.enable [{
      name = "Attic Cache";
      url = "https://cache.${domain}";
      descriptionJa = "Nix バイナリキャッシュ";
      descriptionEn = "Nix Binary Cache";
      logoSvg = builtins.readFile ./attic-logo.svg;
    }];

    environment.etc = {
      "caddy/Caddyfile".text = ''
        {
          admin off
          # Listen on the Tailscale interface only, so vhosts are not
          # reachable from the LAN. TAILSCALE_IP is resolved by the launchd
          # script before Caddy starts; if the Tailscale IP ever changes,
          # Caddy must be restarted to rebind.
          default_bind {$TAILSCALE_IP} 127.0.0.1
        }

        # Common snippets
        (internal_tls) {
          tls internal

          # Access log, shared by every vhost that imports this snippet so
          # logging config lives in one place rather than each service
          # module's own site block. The query string is dropped entirely
          # (not selectively masked) because Pocket ID's OIDC flow puts
          # authorization codes and state values in query parameters on
          # these same Caddy-fronted URLs; a denylist of "sensitive"
          # parameter names would need to be kept in sync with every
          # OIDC-fronted service added in the future, and a missed one
          # would leak a token into the log. Written under /var/log so the
          # existing host-log convention already scraped by the log
          # collector picks it up with no collector-side change.
          log {
            output file /var/log/caddy-access.log
            format filter {
              wrap json
              fields {
                request>uri regexp \?.* ""
              }
            }
          }
        }

        # Prometheus metrics, loopback-only like every other scraped
        # service's metrics port (see modules/monitoring/prometheus.yml).
        # A dedicated port rather than the admin API, since the admin API
        # is disabled above.
        :9091 {
          bind 127.0.0.1
          metrics
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
            respond `${indexHtml}` 200
          }
          handle {
            redir / /index
          }
        }
      '';

      "caddy/sites/attic.caddy".text = ''
        https://cache.${domain} {
          import internal_tls
          reverse_proxy 127.0.0.1:8081
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
            respond `${caHtml}` 200
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
        # caddy config hash: ${caddyEtcHash}
        # Wait for Tailscale so default_bind in the Caddyfile can resolve;
        # KeepAlive restarts us until the IP is available.
        until TAILSCALE_IP=$(${tailscalePackage}/bin/tailscale ip -4 2>/dev/null) && [ -n "$TAILSCALE_IP" ]; do
          echo "Waiting for Tailscale..."
          sleep 2
        done
        export TAILSCALE_IP
        echo "Binding Caddy to Tailscale IP: $TAILSCALE_IP"

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

    # nix's trust of Caddy's internal CA (so binary caches on *.internal are
    # usable) is handled centrally in bootstrap/modules/attic/darwin.nix,
    # covering both this host and every other profile.
  };
}
