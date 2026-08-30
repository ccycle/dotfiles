{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.opencode-web;
  port = 8082;
  oauth2ProxyPort = 4181;
  domain = "${config.networking.hostName}.internal";
  siteUrl = "https://opencode-web.${domain}";

  # Build opencode + shared npm toolchain for launchd from the common lockfile.
  # Resolved here (darwin namespace) because user-launched services run under
  # the system eval, where home-only options are not visible; reading sibling
  # *.lock as data is allowed by Package-by-Feature (only .drv imports differ).
  rawNodeLock = builtins.fromJSON (builtins.readFile ../nodejs/node-tools/package-lock.json);
  excludeOptionalDeps =
    names: lock:
    let
      modulePaths = map (n: "node_modules/${n}") names;
      stripOpt =
        _: pkg:
        if pkg ? optionalDependencies then
          pkg // { optionalDependencies = builtins.removeAttrs pkg.optionalDependencies names; }
        else
          pkg;
    in
    lock
    // {
      packages = builtins.mapAttrs stripOpt (builtins.removeAttrs lock.packages modulePaths);
    };
  fixShrinkwrap =
    lock:
    let
      noIntegrity = builtins.filter (
        p: p != "" && !(lock.packages.${p} ? integrity) && !(lock.packages.${p} ? link)
      ) (builtins.attrNames lock.packages);
    in
    lock
    // {
      packages = builtins.mapAttrs (_: pkg: builtins.removeAttrs pkg [ "hasShrinkwrap" ]) (
        builtins.removeAttrs lock.packages noIntegrity
      );
    };

  npmDeps = pkgs.importNpmLock.buildNodeModules {
    inherit (pkgs) nodejs;
    npmRoot = ../nodejs/node-tools;
    packageLock = fixShrinkwrap (excludeOptionalDeps [ "keytar" ] rawNodeLock);
  };

  nodeTools = pkgs.buildNpmPackage {
    pname = "opencode-web-node-tools";
    version = "1.0.0";
    src = builtins.toFile "opencode-tools-src" "# placeholder\n";
    dontUnpack = true;
    inherit npmDeps;
    npmConfigHook = pkgs.importNpmLock.hooks.linkNodeModulesHook;
    dontNpmInstall = true;
    dontNpmBuild = true;
    installPhase =
      "mkdir -p \$out/bin\n"
      + "ln -s ${npmDeps}/node_modules $out/node_modules\n"
      + "ln -s ${npmDeps}/node_modules/.bin/* $out/bin/\n";
  };
in
{
  options.services.opencode-web = {
    enable = mkEnableOption "OpenCode Web (opencode web + note search)";

    vaultPath = mkOption {
      type = types.str;
      default = "/Users/mfuruki/Obsidian/zettelkasten";
      description = "Path to the Obsidian zettelkasten vault directory.";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "OpenCode Web";
        url = "https://opencode-web.${domain}";
        descriptionJa = "OpenCode Web・ノート検索";
        descriptionEn = "OpenCode Web & Note Search";
        logoSvg = builtins.readFile ./opencode-web-logo.svg;
      }
    ];

    environment.etc."caddy/sites/opencode-web.caddy".text = ''
      http://opencode-web.${domain}, ${siteUrl} {
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

    # Zotero's --local API (used by zot for full-note-body search) only
    # answers while Zotero.app is running; brewCasks.zotero only installs
    # the app, it doesn't keep it open. `open -W` blocks until the app
    # quits, so KeepAlive only relaunches it after an actual crash/quit.
    launchd.user.agents.zotero-keepalive = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/zotero-keepalive.log";
        StandardErrorPath = "/var/tmp/zotero-keepalive.log";
      };
      script = ''
        exec /usr/bin/open -W -j -g "${pkgs.brewCasks.zotero}/Applications/Zotero.app"
      '';
    };

    launchd.user.agents.opencode-web = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/opencode-web.log";
        StandardErrorPath = "/var/tmp/opencode-web.log";
      };
      script = ''
        cd "${cfg.vaultPath}"
        exec ${nodeTools}/bin/opencode web \
          --port ${toString port} \
          --hostname 127.0.0.1
      '';
    };

    services.pocket-id.oidcClients = [
      {
        name = "OpenCode Web";
        clientId = "opencode-web";
        isPublic = false;
        pkceEnabled = false;
        callbackURLs = [ "${siteUrl}/oauth2/callback" ];
        logoutCallbackURLs = [ siteUrl ];
        secretFile = "modules/opencode-web/secrets-${config.networking.hostName}.yaml";
        secretKey = "opencode_web_oidc_client_secret";
      }
    ];

    sops.secrets.opencode_web_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.opencode_web_oauth_cookie_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.opencode-web-oauth2-proxy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/opencode-web-oauth2-proxy.log";
        StandardErrorPath = "/var/log/opencode-web-oauth2-proxy.log";
      };
      script = ''
        export OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.opencode_web_oidc_client_secret.path})
        export OAUTH_COOKIE_SECRET=$(cat ${config.sops.secrets.opencode_web_oauth_cookie_secret.path})

        exec ${pkgs.oauth2-proxy}/bin/oauth2-proxy \
          --provider=oidc \
          --oidc-issuer-url=https://auth.${domain} \
          --provider-ca-file=/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt \
          --client-id=opencode-web \
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
          --whitelist-domain=opencode-web.${domain}
      '';
    };
  };
}
