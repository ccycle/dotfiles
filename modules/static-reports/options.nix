{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.staticReports;
  domain = "${config.networking.hostName}.internal";
  reportsUrl = "https://reports.${domain}";
  # Loopback port oauth2-proxy listens on. Only production Caddy ever
  # reaches it; the tailnet ACL (80/443 only) and 127.0.0.1 binding keep it
  # unreachable from anywhere else.
  oauth2ProxyPort = 4180;
in
{
  options.services.staticReports = {
    enable = mkEnableOption "Tailscale-reachable static file host for reports/artifacts (e2e test reports, coverage, etc.), gated by Pocket ID OIDC via oauth2-proxy";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/static-reports";
      description = ''
        Directory served at https://reports.<hostname>.internal. Anything
        placed in a subdirectory here (e.g. by a worktree's own tooling)
        becomes browsable and downloadable over the tailnet after a Pocket
        ID passkey login. No path is exempt from auth — file_server browse
        would otherwise let anyone enumerate every subdirectory.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [{
      name = "Reports";
      url = reportsUrl;
      descriptionJa = "静的レポート・成果物の閲覧 (テスト結果など)";
      descriptionEn = "Browse static reports/artifacts (test results, etc.)";
      logoSvg = builtins.readFile ./reports-logo.svg;
    }];

    # Confidential OIDC client registered on Pocket ID. The client ID is
    # fixed (plaintext) and matches oauth2-proxy's --client-id below; the
    # secret is captured by scripts/pocket-id-register-clients.sh into this
    # module's per-host secrets file, then read by oauth2-proxy at startup.
    # No allowedGroups: any authenticated Pocket ID user may view reports.
    services.pocket-id.oidcClients = [{
      name = "Reports";
      clientId = "reports";
      isPublic = false;
      pkceEnabled = false;
      # oauth2-proxy's own callback path (see the launchd daemon below).
      callbackURLs = [ "${reportsUrl}/oauth2/callback" ];
      logoutCallbackURLs = [ "${reportsUrl}/oauth2/callback" ];
      secretFile = "modules/static-reports/secrets-${config.networking.hostName}.yaml";
      secretKey = "reports_oidc_client_secret";
    }];

    sops.secrets.reports_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.reports_oauth_cookie_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    environment.etc."newsyslog.d/static-reports.conf".text = ''
      # logfilename                          [owner:group]  mode  count  size  when  flags
      /var/log/static-reports-oauth2-proxy.log  644         7      10240 *     GZ
    '';

    # Static files behind a Pocket ID OIDC gate. The /oauth2/* paths belong
    # to oauth2-proxy itself (sign-in page, authorization-code callback,
    # auth endpoint) and are proxied through unauthenticated; every other
    # path is checked by forward_auth first and only then served by
    # file_server. A 401 from the gate (e.g. while oauth2-proxy is down)
    # redirects the browser to oauth2-proxy's sign-in page. The query string
    # of OAuth callbacks never reaches the access log: internal_tls's log
    # filter already drops all query strings on every vhost.
    environment.etc."caddy/sites/static-reports.caddy".text = ''
      ${reportsUrl} {
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

          root * ${cfg.dataDir}
          file_server browse
        }
      }
    '';

    launchd.daemons.static-reports-oauth2-proxy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/static-reports-oauth2-proxy.log";
        StandardErrorPath = "/var/log/static-reports-oauth2-proxy.log";
      };
      script = ''
        export REPORTS_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.reports_oidc_client_secret.path})
        export REPORTS_OAUTH_COOKIE_SECRET=$(cat ${config.sops.secrets.reports_oauth_cookie_secret.path})

        # This Pocket ID deployment has no SMTP configured, so every
        # account's emailVerified is permanently false; oauth2-proxy
        # would otherwise reject every login with "email in id_token
        # isn't verified".
        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://auth.${domain} \
          --provider-ca-file=/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt \
          --client-id=reports \
          --client-secret="$REPORTS_OIDC_CLIENT_SECRET" \
          --redirect-url=${reportsUrl}/oauth2/callback \
          --http-address=127.0.0.1:${toString oauth2ProxyPort} \
          --upstream=static://202 \
          --email-domain='*' \
          --insecure-oidc-allow-unverified-email=true \
          --set-xauthrequest=true \
          --pass-authorization-header=true \
          --reverse-proxy=true \
          --trusted-proxy-ip=127.0.0.1/32 \
          --cookie-secret="$REPORTS_OAUTH_COOKIE_SECRET" \
          --cookie-secure=true \
          --cookie-csrf-per-request=false \
          --skip-provider-button=true \
          --provider-display-name="Pocket ID" \
          --whitelist-domain=reports.${domain}
      '';
    };

    # User-writable, not root-owned: populated by plain user scripts
    # (e.g. .agents/skills/e2e-test-opencloud/scripts/run.sh) with no
    # launchd/root daemon of its own — Caddy only reads from it.
    system.activationScripts.postActivation.text = ''
      mkdir -p ${cfg.dataDir}
      chown ${config.system.primaryUser} ${cfg.dataDir}
    '';
  };
}
