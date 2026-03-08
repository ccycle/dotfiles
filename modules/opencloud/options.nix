{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.opencloud;
  composeFile = ./compose.yaml;
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

    mountPoint = mkOption {
      type = types.str;
      default = "";
      description = "If set, wait for this path to exist before starting (e.g. /Volumes/KIOXIA for an external drive).";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."newsyslog.d/opencloud.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/opencloud.log                644   7      10240 *     GZ
    '';

    sops.secrets.opencloud_admin_password = {
      sopsFile = ./secrets.yaml;
    };

    launchd.daemons.opencloud-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/opencloud.log";
        StandardErrorPath = "/var/log/opencloud.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") ''
          until [ -d ${cfg.mountPoint} ]; do
            echo "Waiting for volume ${cfg.mountPoint} to be mounted..."
            sleep 10
          done
          echo "Volume ${cfg.mountPoint} is mounted."
        ''}

        until [ -S /Users/mfuruki/.colima/default/docker.sock ]; do
          echo "Waiting for Colima socket..."
          sleep 5
        done

        # Ensure the socket is accessible by root (launchd daemon)
        chmod 666 /Users/mfuruki/.colima/default/docker.sock 2>/dev/null || true

        export DOCKER_HOST="unix:///Users/mfuruki/.colima/default/docker.sock"
        export OPENCLOUD_ADMIN_PASSWORD=$(cat ${config.sops.secrets.opencloud_admin_password.path})
        export OPENCLOUD_DATA_DIR="${cfg.dataDir}"
        export OPENCLOUD_CONFIG_DIR="${cfg.configDir}"

        mkdir -p "$OPENCLOUD_DATA_DIR" "$OPENCLOUD_CONFIG_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
