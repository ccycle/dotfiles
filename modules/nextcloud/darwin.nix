{ pkgs, ... }:

let
  composeFile = pkgs.writeText "nextcloud-docker-compose.yml" ''
    services:
      db:
        image: postgres:16
        volumes:
          - postgres_data:/var/lib/postgresql/data
        environment:
          POSTGRES_DB: nextcloud
          POSTGRES_USER: nextcloud
          POSTGRES_PASSWORD_FILE: /run/secrets/db_password
        restart: unless-stopped

      nextcloud:
        image: nextcloud:30
        ports:
          - "127.0.0.1:8080:80"
        volumes:
          - nextcloud_data:/var/www/html
        environment:
          POSTGRES_HOST: db
          POSTGRES_DB: nextcloud
          POSTGRES_USER: nextcloud
          POSTGRES_PASSWORD_FILE: /run/secrets/db_password
          NEXTCLOUD_TRUSTED_DOMAINS: "nextcloud.mac-mini-m4.internal"
        depends_on:
          - db
        restart: unless-stopped

    volumes:
      postgres_data:
      nextcloud_data:
  '';
in
{
  # DB password and other secrets should be managed via sops-nix:
  #   config.sops.secrets.db_password.path = "/run/secrets/db_password"
  launchd.daemons.nextcloud-compose = {
    serviceConfig = {
      KeepAlive = true;
      RunAtLoad = true;
      StandardOutPath = "/var/log/nextcloud.log";
      StandardErrorPath = "/var/log/nextcloud.log";
    };
    script = ''
      # Wait for Colima to start and expose its socket
      until [ -S /Users/mfuruki/.colima/default/docker.sock ]; do
        echo "Waiting for Colima socket..."
        sleep 5
      done
      export DOCKER_HOST="unix:///Users/mfuruki/.colima/default/docker.sock"
      exec ${pkgs.docker-compose}/bin/docker-compose \
        -f ${composeFile} \
        up --no-build
    '';
  };
}
