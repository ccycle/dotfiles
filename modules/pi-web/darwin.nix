{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.pi-web;
  port = 8083;
  oauth2ProxyPort = 4182;
  domain = "${config.networking.hostName}.internal";
  siteUrl = "https://pi-web.${domain}";

  # Build pi-web + shared npm toolchain for launchd from the common lockfile.
  # Resolved here (darwin namespace) because user-launched services run under
  # the system eval, where home-only options are not visible; reading sibling
  # *.lock as data is allowed by Package-by-Feature (only .drv imports differ).
  rawNodeLock = builtins.fromJSON (builtins.readFile ../nodejs/node-tools/package-lock.json);
  excludeOptionalDeps = names: lock:
    let
      modulePaths = map (n: "node_modules/${n}") names;
      stripOpt = _: pkg:
        if pkg ? optionalDependencies then
          pkg // { optionalDependencies = builtins.removeAttrs pkg.optionalDependencies names; }
        else
          pkg;
    in
      lock // {
        packages =
          builtins.mapAttrs stripOpt (builtins.removeAttrs lock.packages modulePaths);
      };
  fixShrinkwrap =
    lock:
    let
      noIntegrity = builtins.filter (
        p: p != "" && !(lock.packages.${p} ? integrity) && !(lock.packages.${p} ? link)
      ) (builtins.attrNames lock.packages);
    in
    lock // {
      packages = builtins.mapAttrs (
        _: pkg: builtins.removeAttrs pkg [ "hasShrinkwrap" ]
      ) (builtins.removeAttrs lock.packages noIntegrity);
    };

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    inherit (pkgs) nodejs;
    npmRoot = ../nodejs/node-tools;
    packageLock = fixShrinkwrap (excludeOptionalDeps [ "keytar" ] rawNodeLock);
  };

  nodeTools = pkgs.buildNpmPackage {
    pname = "pi-web-node-tools";
    version = "1.0.0";
    src = builtins.toFile "piweb-tools-src" "# placeholder\n";
    dontUnpack = true;
    inherit npmDeps;
    npmConfigHook = pkgs.importNpmLock.hooks.linkNodeModulesHook;
    dontNpmInstall = true;
    dontNpmBuild = true;
    installPhase = "mkdir -p \$out/bin\n" +
      "ln -s ${npmDeps}/node_modules $out/node_modules\n" +
      "ln -s ${npmDeps}/node_modules/.bin/* $out/bin/\n";
  };
in
{
  options.services.pi-web = {
    enable = mkEnableOption "Pi Web (pi coding agent web UI)";

    dataDir = mkOption {
      type = types.str;
      default = "${config.users.users.mfuruki.home}/.pi/agent";
      description = "Path to the pi agent data directory.";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Pi Web";
        url = "https://pi-web.${domain}";
        descriptionJa = "Pi Web・コーディングエージェント";
        descriptionEn = "Pi Web & Coding Agent";
        logoSvg = builtins.readFile ./pi-web-logo.svg;
      }
    ];

    environment.etc."caddy/sites/pi-web.caddy".text = ''
      http://pi-web.${domain}, ${siteUrl} {
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
        name = "Pi Web";
        clientId = "pi-web";
        isPublic = false;
        pkceEnabled = false;
        callbackURLs = [ "${siteUrl}/oauth2/callback" ];
        logoutCallbackURLs = [ siteUrl ];
        secretFile = "modules/pi-web/secrets-${config.networking.hostName}.yaml";
        secretKey = "pi_web_oidc_client_secret";
      }
    ];

    sops.secrets.pi_web_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.pi_web_oauth_cookie_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.pi-web-oauth2-proxy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/pi-web-oauth2-proxy.log";
        StandardErrorPath = "/var/log/pi-web-oauth2-proxy.log";
      };
      script = ''
        export OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.pi_web_oidc_client_secret.path})
        export OAUTH_COOKIE_SECRET=$(cat ${config.sops.secrets.pi_web_oauth_cookie_secret.path})

        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://auth.${domain} \
          --provider-ca-file=/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt \
          --client-id=pi-web \
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
          --whitelist-domain=pi-web.${domain}
      '';
    };

    launchd.user.agents.pi-web = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/pi-web.log";
        StandardErrorPath = "/var/tmp/pi-web.log";
      };
      script = ''
        export PI_WEB_ALLOWED_HOSTS="pi-web.${domain}"
        exec ${nodeTools}/bin/pi-web \
          --port ${toString port} \
          --hostname 127.0.0.1 \
          --no-open
      '';
    };
  };
}
