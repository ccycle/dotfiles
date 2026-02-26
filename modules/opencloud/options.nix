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
  };

  config = mkIf cfg.enable {
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
        until [ -S /Users/mfuruki/.colima/default/docker.sock ]; do
          echo "Waiting for Colima socket..."
          sleep 5
        done
        export DOCKER_HOST="unix:///Users/mfuruki/.colima/default/docker.sock"
        export OPENCLOUD_ADMIN_PASSWORD=$(cat ${config.sops.secrets.opencloud_admin_password.path})
        export OPENCLOUD_DATA_DIR="${cfg.dataDir}"
        export OPENCLOUD_CONFIG_DIR="${cfg.configDir}"

        # Ensure directories exist (may require sudo if outside home)
        mkdir -p "$OPENCLOUD_DATA_DIR" "$OPENCLOUD_CONFIG_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build
      '';
    };
  };
}
