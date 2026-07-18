{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.opencloud;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
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
      description = "If set, wait for this volume to be mounted before starting (e.g. /Volumes/<YOUR_DRIVE>).";
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
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until [ -S /var/run/docker.sock ]; do
          echo "Waiting for OrbStack socket..."
          sleep 5
        done

        export OPENCLOUD_ADMIN_PASSWORD=$(cat ${config.sops.secrets.opencloud_admin_password.path})
        export OPENCLOUD_DATA_DIR="${cfg.dataDir}"
        export OPENCLOUD_CONFIG_DIR="${cfg.configDir}"
        export OPENCLOUD_URL="https://opencloud.${config.networking.hostName}.internal"
        export OPENCLOUD_HOST_DOMAIN="opencloud.${config.networking.hostName}.internal"

        mkdir -p "$OPENCLOUD_DATA_DIR" "$OPENCLOUD_CONFIG_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
