{ config, lib, pkgs, ... }:

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
    services.caddy.portalEntries = [{
      name = "Immich";
      url = "https://immich.${config.networking.hostName}.internal";
      descriptionJa = "フォト＆ビデオ管理";
      descriptionEn = "Photo & Video Management";
      logoSvg = builtins.readFile ./immich-logo.svg;
    }];

    environment.etc."newsyslog.d/immich.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/immich.log                  644   7      10240 *     GZ
    '';

    sops.secrets.immich_db_password = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.immich_oidc_client_id = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.immich_oidc_client_secret = {
      sopsFile = ./secrets.yaml;
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
        export IMMICH_OIDC_ISSUER="https://auth.${config.networking.hostName}.internal"
        export IMMICH_OIDC_CLIENT_ID=$(cat ${config.sops.secrets.immich_oidc_client_id.path})
        export IMMICH_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.immich_oidc_client_secret.path})

        mkdir -p "$IMMICH_UPLOAD_DIR" "$IMMICH_DB_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
