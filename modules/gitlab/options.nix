{ config, lib, pkgs, ... }:

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
    services.caddy.portalEntries = [{
      name = "GitLab";
      url = "https://gitlab.${config.networking.hostName}.internal";
      descriptionJa = "ソースコード管理 & CI/CD";
      descriptionEn = "Source Code Management & CI/CD";
      logoSvg = ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#FC6D26" d="m23.6 9.593-.034-.086L20.3.981a.851.851 0 0 0-.336-.405.875.875 0 0 0-1 .054.875.875 0 0 0-.29.44l-2.206 6.748H7.538L5.332 1.07a.857.857 0 0 0-.29-.441.875.875 0 0 0-1-.054.859.859 0 0 0-.336.405L.433 9.502l-.032.086a6.066 6.066 0 0 0 2.012 7.01l.011.009.03.021 4.976 3.727 2.462 1.863 1.5 1.132a1.009 1.009 0 0 0 1.22 0l1.5-1.132 2.461-1.863 5.006-3.749.013-.01a6.068 6.068 0 0 0 2.009-7.003z"/><path fill="#E24329" d="M12 20.597 17.523 7.83H6.478z"/><path fill="#FCA326" d="m12 20.597-5.522-12.77H1.26z"/><path fill="#E24329" d="M1.26 7.829.433 9.591a1.164 1.164 0 0 0 .422 1.341L12 20.597z"/><path fill="#FCA326" d="M1.26 7.829h5.218L3.738 1.07a.86.86 0 0 0-1.626 0z"/><path fill="#FCA326" d="m12 20.597 5.523-12.77h5.217z"/><path fill="#E24329" d="m22.74 7.829.826 1.762a1.164 1.164 0 0 1-.422 1.341L12 20.597z"/><path fill="#FCA326" d="M22.74 7.829h-5.217l2.74-6.76a.86.86 0 0 1 1.626 0z"/></svg>'';
    }];

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

        mkdir -p "$GITLAB_DATA_DIR" "$GITLAB_CONFIG_DIR" "$GITLAB_LOGS_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
