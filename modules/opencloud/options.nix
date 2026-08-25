{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.opencloud;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
  oidcDomain = "auth.${config.networking.hostName}.internal";
  cspFile = pkgs.writeText "opencloud-csp.yaml" (
    builtins.replaceStrings [ "__OIDC_DOMAIN__" ] [ oidcDomain ] (builtins.readFile ./csp.yaml)
  );
  webApps = pkgs.callPackage ./drv.nix { };
in
{
  options.services.opencloud = {
    enable = mkEnableOption "OpenCloud service";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/opencloud/data";
      description = "Directory for OpenCloud data storage on the host.";
    };

    configDir = mkOption {
      type = types.str;
      default = "/var/lib/opencloud/config";
      description = "Directory for OpenCloud configuration on the host.";
    };

    userFilesDir = mkOption {
      type = types.str;
      default = "/var/lib/opencloud/user-files";
      description = "Directory for OpenCloud user-visible file tree on the host. Mapped to STORAGE_USERS_POSIX_ROOT inside the container.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
      description = "If set, wait for this volume to be mounted before starting (e.g. /Volumes/<YOUR_DRIVE>).";
    };

    appsDir = mkOption {
      type = types.path;
      default = webApps;
      description = "Path to a directory of OpenCloud web apps, served via WEB_ASSET_APPS_PATH and mounted as /var/lib/opencloud/web/assets/apps. Built from Nix (see drv.nix) so updates are reproducible.";
    };

    image = mkOption {
      type = types.str;
      default = "opencloudeu/opencloud-rolling:latest";
      description = "Docker image to run for the opencloud service. Defaults to the upstream image; override per-profile to run a self-built image (see modules/opencloud/build-backend-image.sh) containing out-of-tree backend services not present upstream.";
    };
  };

  config = mkIf cfg.enable {
    # Role-mapping groups and OIDC clients on Pocket ID. Reconcile via
    # scripts/pocket-id-register-clients.sh; see modules/pocket-id/options.nix.
    services.pocket-id.oidcGroups = [
      {
        name = "opencloud_admins";
        friendlyName = "OpenCloud Admins";
        adminGroup = true;
        customClaims = [
          {
            key = "opencloud_role";
            value = "opencloudAdmin";
          }
        ];
      }
      {
        name = "opencloud_spaceadmins";
        friendlyName = "OpenCloud Space Admins";
        customClaims = [
          {
            key = "opencloud_role";
            value = "opencloudSpaceAdmin";
          }
        ];
      }
      {
        name = "opencloud_users";
        friendlyName = "OpenCloud Users";
        customClaims = [
          {
            key = "opencloud_role";
            value = "opencloudUser";
          }
        ];
      }
      {
        name = "opencloud_guests";
        friendlyName = "OpenCloud Guests";
        customClaims = [
          {
            key = "opencloud_role";
            value = "opencloudGuest";
          }
        ];
      }
    ];

    # All OpenCloud clients are public + PKCE (no confidential client
    # exists; see docs/oidc-setup.md). Desktop/mobile IDs are hardcoded in
    # the apps and must match exactly, including case.
    services.pocket-id.oidcClients = [
      {
        name = "OpenCloud Web";
        clientId = "opencloud-web";
        isPublic = true;
        pkceEnabled = true;
        callbackURLs = [
          "https://opencloud.${config.networking.hostName}.internal/"
          "https://opencloud.${config.networking.hostName}.internal/oidc-callback.html"
          "https://opencloud.${config.networking.hostName}.internal/oidc-silent-redirect.html"
        ];
        logoutCallbackURLs = [ "https://opencloud.${config.networking.hostName}.internal" ];
        allowedGroups = [
          "opencloud_admins"
          "opencloud_spaceadmins"
          "opencloud_users"
          "opencloud_guests"
        ];
      }
      {
        name = "OpenCloud Desktop";
        clientId = "OpenCloudDesktop";
        isPublic = true;
        pkceEnabled = true;
        callbackURLs = [
          "http://127.0.0.1"
          "http://localhost"
        ];
        allowedGroups = [
          "opencloud_admins"
          "opencloud_spaceadmins"
          "opencloud_users"
          "opencloud_guests"
        ];
      }
      {
        name = "OpenCloud Android";
        clientId = "OpenCloudAndroid";
        isPublic = true;
        pkceEnabled = true;
        callbackURLs = [ "oc://android.opencloud.eu" ];
        logoutCallbackURLs = [ "oc://android.opencloud.eu" ];
        allowedGroups = [
          "opencloud_admins"
          "opencloud_spaceadmins"
          "opencloud_users"
          "opencloud_guests"
        ];
      }
      {
        name = "OpenCloud iOS";
        clientId = "OpenCloudIOS";
        isPublic = true;
        pkceEnabled = true;
        callbackURLs = [ "oc://ios.opencloud.eu" ];
        logoutCallbackURLs = [ "oc://ios.opencloud.eu" ];
        allowedGroups = [
          "opencloud_admins"
          "opencloud_spaceadmins"
          "opencloud_users"
          "opencloud_guests"
        ];
      }
    ];

    services.caddy.portalEntries = [
      {
        name = "OpenCloud";
        url = "https://opencloud.${config.networking.hostName}.internal";
        descriptionJa = "クラウドストレージ (ownCloud Infinite)";
        descriptionEn = "Cloud Storage (ownCloud Infinite)";
        logoSvg = builtins.readFile ./opencloud-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/opencloud.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/opencloud.log                644   7      10240 *     GZ
    '';

    sops.secrets.opencloud_admin_password = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.opencloud-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/opencloud.log";
        StandardErrorPath = "/var/log/opencloud.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until [ -S /var/run/docker.sock ]; do
          echo "Waiting for OrbStack socket..."
          sleep 5
        done

        export OPENCLOUD_ADMIN_PASSWORD=$(cat ${config.sops.secrets.opencloud_admin_password.path})
        export OPENCLOUD_DATA_DIR="${cfg.dataDir}"
        export OPENCLOUD_CONFIG_DIR="${cfg.configDir}"
        export OPENCLOUD_USER_FILES_DIR="${cfg.userFilesDir}"
        export OPENCLOUD_URL="https://opencloud.${config.networking.hostName}.internal"
        export OPENCLOUD_HOST_DOMAIN="opencloud.${config.networking.hostName}.internal"
        export OPENCLOUD_OIDC_ISSUER="https://auth.${config.networking.hostName}.internal"
        export OPENCLOUD_OIDC_DOMAIN="${oidcDomain}"
        export OPENCLOUD_CSP_FILE="${cspFile}"
        export OPENCLOUD_APPS_DIR="${cfg.appsDir}"
        export OPENCLOUD_IMAGE="${cfg.image}"
        export OPENCLOUD_OIDC_ROLE_CLAIM="opencloud_role"
        export OPENCLOUD_OIDC_CLIENT_ID="opencloud-web"
        export OPENCLOUD_OIDC_PROXY_CLIENT_ID="opencloud-web"

        mkdir -p "$OPENCLOUD_DATA_DIR" "$OPENCLOUD_CONFIG_DIR" "$OPENCLOUD_USER_FILES_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
