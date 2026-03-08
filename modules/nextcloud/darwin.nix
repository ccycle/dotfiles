{ config, lib, pkgs, ... }:

with lib;

let
  composeFile = ./compose.yaml;
in
{
  sops.secrets.nextcloud_db_password = {
    sopsFile = ./secrets.yaml;
  };

  environment.etc."newsyslog.d/nextcloud.conf".text = ''
    # logfilename          [owner:group]  mode  count  size  when  flags
    /var/log/nextcloud.log                644   7      10240 *     GZ
  '';

  launchd.daemons.nextcloud-compose = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/nextcloud.log";
      StandardErrorPath = "/var/log/nextcloud.log";
    };
    script = ''
      until [ -S /var/run/docker.sock ]; do
        echo "Waiting for OrbStack Docker socket..."
        sleep 5
      done

      export NEXTCLOUD_DB_PASSWORD=$(cat ${config.sops.secrets.nextcloud_db_password.path})

      exec ${pkgs.docker-compose}/bin/docker-compose \
        -f ${composeFile} \
        up --no-build --force-recreate
    '';
  };
}
