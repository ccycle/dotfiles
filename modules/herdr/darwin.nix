{
  config,
  lib,
  pkgs,
  herdrWebuiPackage,
  ...
}:

with lib;

let
  cfg = config.services.herdr-webui;
  port = 8787;
  oauth2ProxyPort = 4183;
  domain = "${config.networking.hostName}.internal";
  siteUrl = "https://herdr-webui.${domain}";
in
{
  options.services.herdr-webui = {
    enable = mkEnableOption "Herdr WebUI (browser UI for herdr terminal sessions)";
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Herdr WebUI";
        url = siteUrl;
        descriptionJa = "Herdr WebUI・ターミナルセッション管理";
        descriptionEn = "Herdr WebUI & Terminal Session Manager";
        logoSvg = builtins.readFile ./herdr-webui-logo.svg;
      }
    ];

    environment.etc."caddy/sites/herdr-webui.caddy".text = ''
      http://herdr-webui.${domain}, ${siteUrl} {
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
            @error status 401
            handle_response @error {
              redir * /oauth2/sign_in?rd={scheme}://{host}{uri}
            }
          }

          reverse_proxy 127.0.0.1:${toString port}
        }
      }
    '';

    services.pocket-id.oidcClients = [
      {
        name = "Herdr WebUI";
        clientId = "herdr-webui";
        isPublic = false;
        pkceEnabled = false;
        callbackURLs = [ "${siteUrl}/oauth2/callback" ];
        logoutCallbackURLs = [ siteUrl ];
        secretFile = "modules/herdr/secrets-${config.networking.hostName}.yaml";
        secretKey = "herdr_webui_oidc_client_secret";
      }
    ];

    sops.secrets.herdr_webui_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.herdr_webui_oauth_cookie_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.herdr-webui-oauth2-proxy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/herdr-webui-oauth2-proxy.log";
        StandardErrorPath = "/var/log/herdr-webui-oauth2-proxy.log";
      };
      script = ''
        export OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.herdr_webui_oidc_client_secret.path})
        export OAUTH_COOKIE_SECRET=$(cat ${config.sops.secrets.herdr_webui_oauth_cookie_secret.path})

        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://auth.${domain} \
          --provider-ca-file=/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt \
          --client-id=herdr-webui \
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
          --provider-display-name="Pocket ID" \
          --whitelist-domain=herdr-webui.${domain}
      '';
    };

    # builtin backend mode: herdr-webui runs its own embedded PTY backend, so
    # this is fully independent of the herdr TUI session managed by
    # modules/herdr/home.nix (separate state dir: ~/.config/herdr-webui/).
    launchd.user.agents.herdr-webui = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/herdr-webui.log";
        StandardErrorPath = "/var/tmp/herdr-webui.log";
      };
      script = ''
        exec ${herdrWebuiPackage}/bin/herdr-webui \
          --bind 127.0.0.1:${toString port} \
          --https off \
          --backend-mode builtin \
          --session default
      '';
    };
  };
}
