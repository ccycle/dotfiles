{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.immich;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
in
{
  options.services.immich = {
    enable = mkEnableOption "Immich service";

    uploadDir = mkOption {
      type = types.str;
      default = "/var/lib/immich/upload";
      description = "Directory for Immich photo upload storage on the host.";
    };

    dbDir = mkOption {
      type = types.str;
      default = "/var/lib/immich/db";
      description = "Directory for Immich PostgreSQL database on the host.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
      description = "If set, wait for this volume to be mounted before starting (e.g. /Volumes/<YOUR_DRIVE>).";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Immich";
        url = "https://immich.${config.networking.hostName}.internal";
        descriptionJa = "フォト＆ビデオ管理";
        descriptionEn = "Photo & Video Management";
        logoSvg = builtins.readFile ./immich-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/immich.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/immich.log                  644   7      10240 *     GZ
    '';

    # Confidential OIDC client registered on Pocket ID. The client secret is
    # captured by scripts/pocket-id-register-clients.sh; the client ID is
    # fixed (plaintext) and matches IMMICH_OIDC_CLIENT_ID below.
    services.pocket-id.oidcClients = [
      {
        name = "Immich";
        clientId = "immich";
        isPublic = false;
        pkceEnabled = false;
        callbackURLs = [
          "https://immich.${config.networking.hostName}.internal/auth/login"
          "https://immich.${config.networking.hostName}.internal/user-settings"
          "app.immich:///oauth-callback"
        ];
        logoutCallbackURLs = [
          "https://immich.${config.networking.hostName}.internal/auth/login"
          "https://immich.${config.networking.hostName}.internal/user-settings"
        ];
        secretFile = "modules/immich/secrets-${config.networking.hostName}.yaml";
        secretKey = "immich_oidc_client_secret";
      }
    ];

    sops.secrets.immich_db_password = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };
    sops.secrets.immich_oidc_client_secret = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.immich-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/immich.log";
        StandardErrorPath = "/var/log/immich.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export IMMICH_DB_PASSWORD=$(cat ${config.sops.secrets.immich_db_password.path})
        export IMMICH_UPLOAD_DIR="${cfg.uploadDir}"
        export IMMICH_DB_DIR="${cfg.dbDir}"
        export IMMICH_SERVER_URL="https://immich.${config.networking.hostName}.internal"
        export IMMICH_HOST_DOMAIN="immich.${config.networking.hostName}.internal"

        mkdir -p "$IMMICH_UPLOAD_DIR" "$IMMICH_DB_DIR"

        # Immich has no env-var interface for OAuth (only IMMICH_CONFIG_FILE,
        # which loads a full system-config YAML/JSON). Regenerate that file
        # on every start, next to the other sops-nix runtime secrets rather
        # than on the photo storage volume, so it doesn't persist in backups
        # of the media drive.
        #
        # Owned by the primary user (not root): OrbStack's bind-mount helper
        # runs as that user's own process (there is no root-level container
        # daemon on macOS), so a root-only file is invisible to it and Docker
        # silently substitutes an empty directory for the mount instead of
        # erroring, breaking Immich's config load. This still keeps the file
        # unreadable to any other local account.
        #
        # Must use the real path, not /run: OrbStack's bind-mount source
        # resolution doesn't follow the /run -> private/var/run symlink and
        # silently falls back to mounting an empty directory (verified with
        # `docker run -v /run/...:/test:ro` vs `-v /private/var/run/...`).
        IMMICH_OIDC_CONFIG_DIR="/private/var/run/immich"
        export IMMICH_OIDC_CONFIG_HOST_PATH="$IMMICH_OIDC_CONFIG_DIR/oidc-config.yaml"
        export IMMICH_OIDC_CA_HOST_PATH="$IMMICH_OIDC_CONFIG_DIR/ca.crt"
        rm -rf "$IMMICH_OIDC_CONFIG_DIR"
        mkdir -p "$IMMICH_OIDC_CONFIG_DIR"
        cat > "$IMMICH_OIDC_CONFIG_HOST_PATH" <<EOF
        oauth:
          enabled: true
          issuerUrl: "https://auth.${config.networking.hostName}.internal"
          clientId: "immich"
          clientSecret: "$(cat ${config.sops.secrets.immich_oidc_client_secret.path})"
          autoRegister: true
          storageLabelClaim: preferred_username
        EOF

        # Caddy issues *.internal certs from its own local CA, which the
        # container's system CA bundle doesn't trust. Copy the (public) root
        # cert alongside the config above; NODE_EXTRA_CA_CERTS below points
        # Immich's Node runtime at it for the OIDC discovery/token requests.
        cp /var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt "$IMMICH_OIDC_CA_HOST_PATH"

        chown -R ${config.system.primaryUser} "$IMMICH_OIDC_CONFIG_DIR"
        chmod 700 "$IMMICH_OIDC_CONFIG_DIR"
        chmod 400 "$IMMICH_OIDC_CONFIG_HOST_PATH" "$IMMICH_OIDC_CA_HOST_PATH"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
