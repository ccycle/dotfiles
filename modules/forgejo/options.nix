{
  config,
  lib,
  pkgs,
  ...
}:

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
      type = types.listOf (
        types.submodule {
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
        }
      );
      default = [ ];
      description = ''
        Repositories to keep push-mirrored from this Forgejo instance to GitHub.
        Each entry must already exist as a repository in Forgejo (pushed there manually
        at least once) before its mirror is created.
      '';
    };

    runnerEnable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Register and run a Forgejo Actions runner directly on this host via
        launchd, with native ("host") job execution rather than a container,
        so CI jobs can perform real aarch64-darwin `nix build` runs. See
        modules/forgejo/design.md.
      '';
    };

    runnerDataDir = mkOption {
      type = types.str;
      default = "/var/lib/forgejo-runner";
      description = "Working directory for the forgejo-runner process: holds its config.yaml and its self-generated registration secret.";
    };

    runnerLabels = mkOption {
      type = types.listOf types.str;
      default = [
        "macos-latest:host"
        "native:host"
      ];
      description = ''
        Labels this runner advertises to `runs-on`. "host" execution means
        job steps run directly on this machine with no isolation - do not
        add labels here for untrusted-contributor workflows.
      '';
    };

    branchProtections = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            owner = mkOption {
              type = types.str;
              description = "Owner of the repository on this Forgejo instance.";
            };
            repo = mkOption {
              type = types.str;
              description = "Name of the repository on this Forgejo instance.";
            };
            branch = mkOption {
              type = types.str;
              default = "main";
              description = "Branch (or glob rule) to protect.";
            };
            statusCheckContexts = mkOption {
              type = types.listOf types.str;
              description = ''
                Required commit-status contexts - the Forgejo Actions job
                context string shown in the repository's Checks UI. No
                default on purpose: confirm the exact context string against
                a live workflow run before deploying, since a mismatched
                context permanently blocks merges on a check that never
                reports.
              '';
            };
          };
        }
      );
      default = [ ];
      description = ''
        Branches to keep protected via the Forgejo API: force-push disabled
        (the API has no separate toggle for this - it's implicit whenever a
        branch is protected), direct push allowed, and the given status
        checks required.
      '';
    };

    backupEnable = mkOption {
      type = types.bool;
      default = false;
      description = "Run a daily `forgejo dump` (git + config/DB) into dataDir/dumps on the external drive.";
    };

    backupRetentionCount = mkOption {
      type = types.int;
      default = 7;
      description = "Number of dump generations to keep.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      # Confidential OIDC client registered on Pocket ID. The client secret
      # is captured by scripts/pocket-id-register-clients.sh; the client ID
      # is fixed (plaintext) and matches FORGEJO_OIDC_CLIENT_ID below.
      services.pocket-id.oidcClients = [
        {
          name = "Forgejo";
          clientId = "forgejo";
          isPublic = false;
          pkceEnabled = false;
          # Path includes the auth source name ("PocketID", set via
          # `forgejo admin auth add-oauth --name` in forgejo-oidc-bootstrap
          # above) -- Forgejo's OAuth2 callback route is
          # /user/oauth2/<source-name>/callback, not /user/oauth2/callback.
          callbackURLs = [
            "https://forgejo.${config.networking.hostName}.internal/user/oauth2/PocketID/callback"
          ];
          logoutCallbackURLs = [
            "https://forgejo.${config.networking.hostName}.internal/user/oauth2/PocketID/callback"
          ];
          secretFile = "modules/forgejo/secrets.yaml";
          secretKey = "forgejo_oidc_client_secret";
        }
      ];

      # Pocket ID's "groups" claim carries each group's `name` field verbatim
      # (not friendlyName) -- forgejo-oidc-bootstrap's --admin-group value
      # below must match this `name` exactly.
      services.pocket-id.oidcGroups = [
        {
          name = "forgejo_admins";
          friendlyName = "Forgejo Admins";
          adminGroup = true;
        }
      ];

      sops.secrets.forgejo_oidc_client_secret = {
        sopsFile = ./secrets.yaml;
      };

      services.caddy.portalEntries = [
        {
          name = "Forgejo";
          url = "https://forgejo.${config.networking.hostName}.internal";
          descriptionJa = "軽量 Git フォージ";
          descriptionEn = "Lightweight Git Forge";
          logoSvg = builtins.readFile ./forgejo-logo.svg;
        }
      ];

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

          # Caddy issues *.internal certs from its own local CA, which the
          # container's system CA bundle doesn't trust. Copy the (public)
          # root cert into the container via a bind mount (see compose.yaml)
          # so Forgejo's OIDC client can verify Pocket ID's TLS certificate.
          FORGEJO_CADDY_CA_SRC="/var/lib/caddy/caddy/pki/authorities/${config.networking.hostName}/root.crt"
          FORGEJO_CADDY_CA_DST="''${FORGEJO_DATA_DIR}/caddy-ca.crt"

          # Wait for Caddy to generate its CA certificate (up to 60 seconds)
          attempts=0
          until [ -f "$FORGEJO_CADDY_CA_SRC" ]; do
            attempts=$((attempts + 1))
            if [ "$attempts" -ge 12 ]; then
              echo "ERROR: Caddy CA cert not found at $FORGEJO_CADDY_CA_SRC after waiting; OIDC will fail."
              break
            fi
            echo "Waiting for Caddy CA cert at $FORGEJO_CADDY_CA_SRC..."
            sleep 5
          done

          if [ -f "$FORGEJO_CADDY_CA_SRC" ]; then
            ${pkgs.coreutils}/bin/cp "$FORGEJO_CADDY_CA_SRC" "$FORGEJO_CADDY_CA_DST"
            echo "Copied Caddy CA cert to $FORGEJO_CADDY_CA_DST"
          else
            echo "ERROR: Caddy CA cert not found; creating empty file."
            touch "$FORGEJO_CADDY_CA_DST"
          fi
          export FORGEJO_CADDY_CA_CERT="$FORGEJO_CADDY_CA_DST"

          mkdir -p "$FORGEJO_DATA_DIR"

          exec ${pkgs.docker-compose}/bin/docker-compose \
            -f ${composeFile} \
            up --no-build --force-recreate
        '';
      };

      # Forgejo has no app.ini/env-var way to declare an external OIDC login
      # source (only account auto-registration behavior, set in
      # compose.yaml's [oauth2_client] vars, is configurable that way). The
      # source itself must go through `forgejo admin auth add-oauth` (CLI) or
      # the web UI, so bootstrap it idempotently here, the same pattern as
      # forgejo-mirror-bootstrap below.
      launchd.daemons.forgejo-oidc-bootstrap = {
        serviceConfig = {
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-oidc-bootstrap.log";
          StandardErrorPath = "/var/log/forgejo-oidc-bootstrap.log";
        };
        script = ''
          set -euo pipefail

          # docker-compose parses the whole compose file (including the
          # volumes section) even for `exec`, so these must be set even
          # though exec doesn't start a new container.
          export FORGEJO_DATA_DIR="${cfg.dataDir}"
          export FORGEJO_EXTERNAL_URL="https://forgejo.${config.networking.hostName}.internal"
          export FORGEJO_CADDY_CA_CERT="${cfg.dataDir}/caddy-ca.crt"

          FORGEJO_OIDC_CLIENT_ID="forgejo"
          FORGEJO_OIDC_CLIENT_SECRET=$(cat ${config.sops.secrets.forgejo_oidc_client_secret.path})
          FORGEJO_OIDC_DISCOVERY_URL="https://auth.${config.networking.hostName}.internal/.well-known/openid-configuration"

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

          # -u git: the container's entrypoint drops root -> git before
          # exec'ing the server, but `docker compose exec` attaches as root
          # by default, and forgejo refuses to run its CLI as root.
          #
          # Caddy's CA cert is trusted by the container's own entrypoint
          # (see compose.yaml) before the gitea process execs, since Go
          # caches its certificate pool at process start and never re-reads
          # it from disk -- patching the trust store via `docker exec`
          # after the container is already up cannot affect a process
          # that's already running.

          existing=$(${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo forgejo admin auth list 2>/dev/null || true)
          source_id=$(echo "$existing" | grep "PocketID" | awk '{print $1}')

          if [ -z "$source_id" ]; then
            ${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo \
              forgejo admin auth add-oauth \
                --name PocketID \
                --provider openidConnect \
                --key "$FORGEJO_OIDC_CLIENT_ID" \
                --secret "$FORGEJO_OIDC_CLIENT_SECRET" \
                --auto-discover-url "$FORGEJO_OIDC_DISCOVERY_URL" \
                --group-claim-name groups \
                --admin-group forgejo_admins \
              && echo "Created OIDC authentication source 'PocketID'." \
              || echo "Failed to create OIDC authentication source 'PocketID'."
          else
            # Re-run every boot so group-claim/admin-group changes made here
            # take effect on an already-created source without a manual step.
            ${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo \
              forgejo admin auth update-oauth \
                --id "$source_id" \
                --group-claim-name groups \
                --admin-group forgejo_admins \
              && echo "OIDC authentication source 'PocketID' (id $source_id) reconciled." \
              || echo "Failed to reconcile OIDC authentication source 'PocketID' (id $source_id)."
          fi
        '';
      };
    }
    (mkIf (cfg.pushMirrors != [ ] || cfg.branchProtections != [ ]) {
      # Shared by both push-mirror and branch-protection bootstrap jobs, so
      # it's declared once here rather than in either feature's own mkIf
      # block - declaring it in both would be a duplicate definition.
      sops.secrets.forgejo_api_token = {
        sopsFile = ./secrets.yaml;
      };
    })
    (mkIf (cfg.pushMirrors != [ ]) {
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
    (mkIf (cfg.branchProtections != [ ]) {
      launchd.daemons.forgejo-branch-protection-bootstrap = {
        serviceConfig = {
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-branch-protection-bootstrap.log";
          StandardErrorPath = "/var/log/forgejo-branch-protection-bootstrap.log";
        };
        script = ''
          set -euo pipefail

          FORGEJO_API="http://127.0.0.1:3000/api/v1"
          FORGEJO_TOKEN=$(cat ${config.sops.secrets.forgejo_api_token.path})

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

          ${concatMapStringsSep "\n" (p: ''
            echo "Applying branch protection for ${p.owner}/${p.repo}@${p.branch}"

            # No dedicated "block force push" field exists in the Forgejo API:
            # force-push is implicitly disallowed on any protected branch.
            # See https://codeberg.org/forgejo/forgejo/src/branch/forgejo/cmd/../models/actions
            # (BranchProtection struct) - enable_push + enable_status_check
            # is the "direct push allowed, CI required" combination.
            BODY=$(${pkgs.jq}/bin/jq -n \
              --arg branch_name "${p.branch}" \
              --argjson status_check_contexts '${builtins.toJSON p.statusCheckContexts}' \
              '{
                branch_name: $branch_name,
                enable_push: true,
                enable_push_whitelist: false,
                enable_status_check: true,
                status_check_contexts: $status_check_contexts,
                require_signed_commits: false
              }')

            existing_status=$(${pkgs.curl}/bin/curl -s -o /dev/null -w '%{http_code}' \
              -H "Authorization: token $FORGEJO_TOKEN" \
              "$FORGEJO_API/repos/${p.owner}/${p.repo}/branch_protections/${p.branch}")

            if [ "$existing_status" = "200" ]; then
              ${pkgs.curl}/bin/curl -sf -X PATCH \
                -H "Authorization: token $FORGEJO_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$BODY" \
                "$FORGEJO_API/repos/${p.owner}/${p.repo}/branch_protections/${p.branch}" \
                && echo "Updated branch protection for ${p.owner}/${p.repo}@${p.branch}." \
                || echo "Failed to update branch protection for ${p.owner}/${p.repo}@${p.branch}."
            else
              ${pkgs.curl}/bin/curl -sf -X POST \
                -H "Authorization: token $FORGEJO_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$BODY" \
                "$FORGEJO_API/repos/${p.owner}/${p.repo}/branch_protections" \
                && echo "Created branch protection for ${p.owner}/${p.repo}@${p.branch}." \
                || echo "Failed to create branch protection for ${p.owner}/${p.repo}@${p.branch}."
            fi
          '') cfg.branchProtections}
        '';
      };
    })
    (mkIf cfg.runnerEnable {
      environment.etc."newsyslog.d/forgejo-runner.conf".text = ''
        # logfilename                              [owner:group]  mode  count  size  when  flags
        /var/log/forgejo-runner.log                                644   7      10240 *     GZ
        /var/log/forgejo-runner-bootstrap.log                      644   7      10240 *     GZ
      '';

      # Registers (idempotently - see `forgejo-cli actions register`'s own
      # docs) a runner identity on every boot rather than gating on a marker
      # file, since the shared secret and config.yaml already make repeat
      # registration a no-op. This also means labels/name changes here take
      # effect on the next rebuild without manual intervention.
      launchd.daemons.forgejo-runner-bootstrap = {
        serviceConfig = {
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-runner-bootstrap.log";
          StandardErrorPath = "/var/log/forgejo-runner-bootstrap.log";
        };
        script = ''
          set -euo pipefail

          # docker-compose parses the whole compose file (including the
          # volumes section) even for `exec`, so these must be set even
          # though exec doesn't start a new container - same requirement
          # as forgejo-oidc-bootstrap above.
          export FORGEJO_DATA_DIR="${cfg.dataDir}"
          export FORGEJO_EXTERNAL_URL="https://forgejo.${config.networking.hostName}.internal"
          export FORGEJO_CADDY_CA_CERT="${cfg.dataDir}/caddy-ca.crt"

          RUNNER_DIR="${cfg.runnerDataDir}"
          mkdir -p "$RUNNER_DIR"
          SECRET_FILE="$RUNNER_DIR/secret"
          CONFIG_FILE="$RUNNER_DIR/config.yaml"

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

          if [ ! -f "$SECRET_FILE" ]; then
            ${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo \
              forgejo forgejo-cli actions generate-secret > "$SECRET_FILE"
            chmod 600 "$SECRET_FILE"
          fi
          SECRET=$(cat "$SECRET_FILE")

          UUID=$(${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo \
            forgejo forgejo-cli actions register \
            --secret "$SECRET" \
            --name "${config.networking.hostName}" \
            --labels "${concatStringsSep "," cfg.runnerLabels}")

          if [ ! -f "$CONFIG_FILE" ]; then
            ${pkgs.forgejo-runner}/bin/forgejo-runner generate-config > "$CONFIG_FILE"
          fi

          # Loopback, not the https://forgejo.*.internal hostname: this
          # runner always runs on the same host as the server (see
          # design.md), and forgejo-runner's Go binary uses the pure-Go
          # DNS resolver, which only reads /etc/resolv.conf and ignores
          # macOS's per-domain /etc/resolver/internal split-DNS entry -
          # so it cannot resolve *.internal names even though every other
          # tool on this host (curl, browsers, dscacheutil) can. Confirmed
          # live: the runner logged "lookup forgejo.*.internal ... no such
          # host" against the ISP nameservers from /etc/resolv.conf.
          export RUNNER_URL="http://127.0.0.1:3000/"
          export RUNNER_UUID="$UUID"
          export RUNNER_TOKEN_URL="file:$SECRET_FILE"

          ${pkgs.yq-go}/bin/yq -i '
            .server.connections.forgejo.url = strenv(RUNNER_URL) |
            .server.connections.forgejo.uuid = strenv(RUNNER_UUID) |
            .server.connections.forgejo.token_url = strenv(RUNNER_TOKEN_URL) |
            .runner.labels = ${builtins.toJSON cfg.runnerLabels}
          ' "$CONFIG_FILE"
        '';
      };

      launchd.daemons.forgejo-runner = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-runner.log";
          StandardErrorPath = "/var/log/forgejo-runner.log";
        };
        script = ''
          CONFIG_FILE="${cfg.runnerDataDir}/config.yaml"

          # LaunchDaemons (unlike LaunchAgents) get no HOME from launchd -
          # it's unset, so job steps that expand `~` or `$HOME/.cache`
          # resolve to "/.cache" and fail on the read-only root volume.
          # Confirmed live: a job crashed with "mkdir /.cache: read-only
          # file system" before this was added.
          export HOME="${cfg.runnerDataDir}"

          until [ -f "$CONFIG_FILE" ]; do
            echo "Waiting for forgejo-runner-bootstrap to write $CONFIG_FILE..."
            sleep 5
          done

          exec ${pkgs.forgejo-runner}/bin/forgejo-runner daemon --config "$CONFIG_FILE"
        '';
      };
    })
    (mkIf cfg.backupEnable {
      environment.etc."newsyslog.d/forgejo-backup.conf".text = ''
        # logfilename                    [owner:group]  mode  count  size  when  flags
        /var/log/forgejo-backup.log                      644   7      10240 *     GZ
      '';

      launchd.daemons.forgejo-backup = {
        serviceConfig = {
          RunAtLoad = true;
          StandardOutPath = "/var/log/forgejo-backup.log";
          StandardErrorPath = "/var/log/forgejo-backup.log";
          StartCalendarInterval = [
            {
              Hour = 3;
              Minute = 0;
            }
          ];
        };
        script = ''
          set -euo pipefail

          # dataDir is the host-visible side of the bind mount at container
          # path /data (see compose.yaml), so dump files land here directly
          # without a docker cp step.
          DUMP_DIR="${cfg.dataDir}/dumps"
          mkdir -p "$DUMP_DIR"

          if ! ${pkgs.curl}/bin/curl -sf "http://127.0.0.1:3000/api/healthz" >/dev/null 2>&1; then
            echo "Forgejo is not healthy, skipping today's backup."
            exit 0
          fi

          DUMP_FILE="/data/dumps/forgejo-dump-$(date +%Y%m%d-%H%M%S).zip"
          ${pkgs.docker-compose}/bin/docker-compose -f ${composeFile} exec -T -u git forgejo \
            forgejo dump --file "$DUMP_FILE" --type zip

          ls -1t "$DUMP_DIR"/forgejo-dump-*.zip 2>/dev/null \
            | tail -n +$((${toString cfg.backupRetentionCount} + 1)) \
            | ${pkgs.findutils}/bin/xargs -r rm -f

          echo "Backup complete: $DUMP_FILE ($(ls -1 "$DUMP_DIR"/forgejo-dump-*.zip | wc -l) generations retained)"
        '';
      };
    })
  ]);
}
