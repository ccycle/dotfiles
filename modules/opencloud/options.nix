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
    services.caddy.portalEntries = [{
      name = "OpenCloud";
      url = "https://opencloud.${config.networking.hostName}.internal";
      descriptionJa = "クラウドストレージ (ownCloud Infinite)";
      descriptionEn = "Cloud Storage (ownCloud Infinite)";
      logoSvg = ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512"><path fill="#e2baff" d="m256 373.2 21.5-12.4V271l77.3-44.6v-24.8l-21.5-12.4-77.8 44.9-76.7-44.3-21.5 12.4V227l77.3 44.6v89.2zm197.2-259.3L256 0 58.8 113.9v49.6L256 49.6l197.2 113.9zm0 234.7L256 462.4 58.8 348.6v49.6L256 512l197.2-113.9z"/></svg>'';
    }];

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
        export OPENCLOUD_OIDC_ISSUER="https://auth.${config.networking.hostName}.internal"
        export OPENCLOUD_OIDC_DOMAIN="auth.${config.networking.hostName}.internal"

        mkdir -p "$OPENCLOUD_DATA_DIR" "$OPENCLOUD_CONFIG_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
