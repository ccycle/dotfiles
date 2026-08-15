{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.forgejo;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
in
{
  options.services.forgejo = {
    enable = mkEnableOption "Forgejo git forge service";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo/data";
    };

    dataVolume = mkOption {
      type = types.str;
      default = "forgejo-gitea-data";
      description = "Docker named volume holding Forgejo's SQLite database and small app state (mounted over dataDir/gitea). A named volume lives on VM-internal storage (not virtiofs), which is what SQLite requires; see modules/forgejo/design.md.";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
    };

    pushMirrors = mkOption {
      type = types.listOf (types.submodule {
        options = {
          owner = mkOption {
            type = types.str;
            description = "Owner of the repository on this Forgejo instance.";
          };
          repo = mkOption {
            type = types.str;
            description = "Name of the repository on this Forgejo instance.";
          };
          remoteUrl = mkOption {
            type = types.str;
            description = "HTTPS clone URL of the GitHub mirror target, without embedded credentials.";
          };
        };
      });
      default = [ ];
      description = ''
        Repositories to keep push-mirrored from this Forgejo instance to GitHub.
        Each entry must already exist as a repository in Forgejo (pushed there manually
        at least once) before its mirror is created.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      sops.secrets.forgejo_oidc_client_id = {
        sopsFile = ./secrets.yaml;
      };
      sops.secrets.forgejo_oidc_client_secret = {
        sopsFile = ./secrets.yaml;
      };

      services.caddy.portalEntries = [{
        name = "Forgejo";
        url = "https://forgejo.${config.networking.hostName}.internal";
        descriptionJa = "軽量 Git フォージ";
        descriptionEn = "Lightweight Git Forge";
        logoSvg = builtins.readFile ./forgejo-logo.svg;
      }];

      environment.etc."newsyslog.d/forgejo.conf".text = ''
        # logfilename          [owner:group]  mode  count  size  when  flags
        /var/log/forgejo.log                  644   7      10240 *     GZ
      '';

      environment.etc."caddy/sites/forgejo.caddy".text = ''
        https://forgejo.${config.networking.hostName}.internal {
          import internal_tls
          reverse_proxy 127.0.0.1:3000
        }
      '';

      launchd.daemons.forgejo-compose = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo.log";
          StandardErrorPath = "/var/log/forgejo.log";
        };
        script = ''
          ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

          until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
            echo "Waiting for Docker to be ready..."
            sleep 5
          done

          export FORGEJO_DATA_DIR="${cfg.dataDir}"
          export FORGEJO_EXTERNAL_URL="https://forgejo.${config.networking.hostName}.internal"
          export FORGEJO_OIDC_CLIENT_ID=$(cat ${config.sops.secrets.forgejo_oidc_client_id.path})
          export FORGEJO_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.forgejo_oidc_client_secret.path})
          export FORGEJO_OIDC_DISCOVERY_URL="https://auth.${config.networking.hostName}.internal/.well-known/openid-configuration"

          mkdir -p "$FORGEJO_DATA_DIR"

          exec ${pkgs.docker-compose}/bin/docker-compose \
            -f ${composeFile} \
            up --no-build --force-recreate
        '';
      };
    }
    (mkIf (cfg.pushMirrors != [ ]) {
      sops.secrets.forgejo_api_token = {
        sopsFile = ./secrets.yaml;
      };
      sops.secrets.github_push_mirror_token = {
        sopsFile = ./secrets.yaml;
      };

      launchd.daemons.forgejo-mirror-bootstrap = {
        serviceConfig = {
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-mirror-bootstrap.log";
          StandardErrorPath = "/var/log/forgejo-mirror-bootstrap.log";
        };
        script = ''
          set -euo pipefail

          FORGEJO_API="http://127.0.0.1:3000/api/v1"
          FORGEJO_TOKEN=$(cat ${config.sops.secrets.forgejo_api_token.path})
          GITHUB_TOKEN=$(cat ${config.sops.secrets.github_push_mirror_token.path})

          attempts=0
          until ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:3000/api/healthz" >/dev/null 2>&1; do
            attempts=$((attempts + 1))
            if [ "$attempts" -ge 30 ]; then
              echo "Forgejo did not become healthy in time, giving up for this run."
              exit 0
            fi
            echo "Waiting for Forgejo to be ready..."
            sleep 10
          done

          ${concatMapStringsSep "\n" (m: ''
            echo "Reconciling push mirror for ${m.owner}/${m.repo} -> ${m.remoteUrl}"

            repo_status=$(${pkgs.curl}/bin/curl -s -o /dev/null -w '%{http_code}' \
              -H "Authorization: token $FORGEJO_TOKEN" \
              "$FORGEJO_API/repos/${m.owner}/${m.repo}")

            if [ "$repo_status" != "200" ]; then
              echo "Repository ${m.owner}/${m.repo} does not exist on Forgejo yet (HTTP $repo_status), skipping. Push it once first."
            else
              remote_host_path=$(echo "${m.remoteUrl}" | ${pkgs.gnused}/bin/sed -E 's#^https?://##')
              already_mirrored=$(${pkgs.curl}/bin/curl -s \
                -H "Authorization: token $FORGEJO_TOKEN" \
                "$FORGEJO_API/repos/${m.owner}/${m.repo}/push_mirrors" \
                | ${pkgs.jq}/bin/jq -e --arg host "$remote_host_path" \
                  '[.[] | select(.remote_address | contains($host))] | length > 0' 2>/dev/null || echo false)

              if [ "$already_mirrored" = "true" ]; then
                echo "Push mirror for ${m.owner}/${m.repo} already exists, skipping."
              else
                ${pkgs.curl}/bin/curl -sf -X POST \
                  -H "Authorization: token $FORGEJO_TOKEN" \
                  -H "Content-Type: application/json" \
                  -d "$(${pkgs.jq}/bin/jq -n \
                    --arg remote_address "${m.remoteUrl}" \
                    --arg remote_username "x-access-token" \
                    --arg remote_password "$GITHUB_TOKEN" \
                    --arg interval "8h0m0s" \
                    '{remote_address: $remote_address, remote_username: $remote_username, remote_password: $remote_password, interval: $interval, sync_on_commit: true}')" \
                  "$FORGEJO_API/repos/${m.owner}/${m.repo}/push_mirrors" \
                  && echo "Created push mirror for ${m.owner}/${m.repo}." \
                  || echo "Failed to create push mirror for ${m.owner}/${m.repo}."
              fi
            fi
          '') cfg.pushMirrors}
        '';
      };
    })
  ]);
}
