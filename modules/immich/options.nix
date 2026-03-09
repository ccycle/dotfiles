{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.immich;
  composeFile = ./compose.yaml;
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
      description = "If set, wait for this path to exist before starting (e.g. /Volumes/KIOXIA for an external drive).";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."newsyslog.d/immich.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/immich.log                  644   7      10240 *     GZ
    '';

    sops.secrets.immich_db_password = {
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
        ${optionalString (cfg.mountPoint != "") ''
          until [ -d ${cfg.mountPoint} ]; do
            echo "Waiting for volume ${cfg.mountPoint} to be mounted..."
            sleep 10
          done
          echo "Volume ${cfg.mountPoint} is mounted."
        ''}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export IMMICH_DB_PASSWORD=$(cat ${config.sops.secrets.immich_db_password.path})
        export IMMICH_UPLOAD_DIR="${cfg.uploadDir}"
        export IMMICH_DB_DIR="${cfg.dbDir}"

        mkdir -p "$IMMICH_UPLOAD_DIR" "$IMMICH_DB_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
