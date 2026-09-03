{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.navidrome;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
  domain = "${config.networking.hostName}.internal";
  siteUrl = "https://navidrome.${domain}";
  oauth2ProxyPort = 4184;
in
{
  options.services.navidrome = {
    enable = mkEnableOption "Navidrome music streaming server";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/navidrome/data";
      description = "Directory for Navidrome's application data (SQLite DB, cache).";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
    };

    musicDir = mkOption {
      type = types.str;
      default = "";
      description = "Path to the music library on the external storage volume.";
    };

    port = mkOption {
      type = types.int;
      default = 4533;
      description = "Port Navidrome listens on inside the container (and on 127.0.0.1).";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Navidrome";
        url = siteUrl;
        descriptionJa = "音楽ストリーミングサーバー";
        descriptionEn = "Music Streaming Server";
        logoSvg = builtins.readFile ./navidrome-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/navidrome.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/navidrome.log                  644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/navidrome.caddy".text = ''
      ${siteUrl} {
        import internal_tls

        handle /oauth2/* {
          reverse_proxy 127.0.0.1:${toString oauth2ProxyPort} {
            header_up X-Real-IP {remote_host}
            header_up X-Forwarded-Uri {uri}
          }
        }

        handle {
          forward_auth 127.0.0.1:${toString oauth2ProxyPort} {
            uri /oauth2/auth
            header_up X-Real-IP {remote_host}
            copy_headers X-Auth-Request-User X-Auth-Request-Email
            @error status 401
            handle_response @error {
              redir * /oauth2/sign_in?rd={scheme}://{host}{uri}
            }
          }

          reverse_proxy 127.0.0.1:${toString cfg.port} {
            header_up Remote-User {http.miss.X-Auth-Request-User}
            header_up Remote-Email {http.miss.X-Auth-Request-Email}
          }
        }
      }
    '';

    services.pocket-id.oidcClients = [
      {
        name = "Navidrome";
        clientId = "navidrome";
        isPublic = false;
        pkceEnabled = false;
        callbackURLs = [ "${siteUrl}/oauth2/callback" ];
        logoutCallbackURLs = [ siteUrl ];
        secretFile = "modules/navidrome/secrets-${config.networking.hostName}.yaml";
        secretKey = "navidrome_oidc_client_secret";
      }
    ];

    sops.secrets.navidrome_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.navidrome_oauth_cookie_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.navidrome-oauth2-proxy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/navidrome-oauth2-proxy.log";
        StandardErrorPath = "/var/log/navidrome-oauth2-proxy.log";
      };
      script = ''
        export OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.navidrome_oidc_client_secret.path})
        export OAUTH_COOKIE_SECRET=$(cat ${config.sops.secrets.navidrome_oauth_cookie_secret.path})

        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://auth.${domain} \
          --provider-ca-file=/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt \
          --client-id=navidrome \
          --client-secret="$OIDC_CLIENT_SECRET" \
          --redirect-url=${siteUrl}/oauth2/callback \
          --http-address=127.0.0.1:${toString oauth2ProxyPort} \
          --upstream=static://202 \
          --email-domain='*' \
          --insecure-oidc-allow-unverified-email=true \
          --set-xauthrequest=true \
          --pass-authorization-header=true \
          --reverse-proxy=true \
          --trusted-proxy-ip=127.0.0.1/32 \
          --cookie-secret="$OAUTH_COOKIE_SECRET" \
          --cookie-secure=true \
          --cookie-csrf-per-request=false \
          --skip-provider-button=true \
          --provider-display-name="Pocket ID"
      '';
    };

    launchd.daemons.navidrome-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/navidrome.log";
        StandardErrorPath = "/var/log/navidrome.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export NAVIDROME_DATA_DIR="${cfg.dataDir}"
        export NAVIDROME_MUSIC_DIR="${cfg.musicDir}"
        export NAVIDROME_PORT="${toString cfg.port}"

        mkdir -p "$NAVIDROME_DATA_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
