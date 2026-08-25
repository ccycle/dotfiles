{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.gitlab;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
in
{
  options.services.gitlab = {
    enable = mkEnableOption "GitLab CE service";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/gitlab/data";
      description = "Directory for GitLab data storage on the host.";
    };

    configDir = mkOption {
      type = types.str;
      default = "/var/lib/gitlab/config";
      description = "Directory for GitLab configuration on the host.";
    };

    logsDir = mkOption {
      type = types.str;
      default = "/var/lib/gitlab/logs";
      description = "Directory for GitLab logs on the host.";
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
        name = "GitLab";
        url = "https://gitlab.${config.networking.hostName}.internal";
        descriptionJa = "ソースコード管理 & CI/CD";
        descriptionEn = "Source Code Management & CI/CD";
        logoSvg = builtins.readFile ./gitlab-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/gitlab.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/gitlab.log                   644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/gitlab.caddy".text = ''
      https://gitlab.${config.networking.hostName}.internal {
        import internal_tls
        reverse_proxy 127.0.0.1:8929
      }
    '';

    sops.secrets.gitlab_root_password = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.gitlab_oidc_client_id = {
      sopsFile = ./secrets.yaml;
    };
    sops.secrets.gitlab_oidc_client_secret = {
      sopsFile = ./secrets.yaml;
    };

    launchd.daemons.gitlab-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/gitlab.log";
        StandardErrorPath = "/var/log/gitlab.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export GITLAB_ROOT_PASSWORD=$(cat ${config.sops.secrets.gitlab_root_password.path})
        export GITLAB_DATA_DIR="${cfg.dataDir}"
        export GITLAB_CONFIG_DIR="${cfg.configDir}"
        export GITLAB_LOGS_DIR="${cfg.logsDir}"
        export GITLAB_EXTERNAL_URL="https://gitlab.${config.networking.hostName}.internal"
        export GITLAB_OIDC_ISSUER="https://auth.${config.networking.hostName}.internal"
        export GITLAB_OIDC_CLIENT_ID=$(cat ${config.sops.secrets.gitlab_oidc_client_id.path})
        export GITLAB_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.gitlab_oidc_client_secret.path})

        mkdir -p "$GITLAB_DATA_DIR" "$GITLAB_CONFIG_DIR" "$GITLAB_LOGS_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
