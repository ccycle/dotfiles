{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.pocket-id;
  composeFile = ./compose.yaml;
  domain = "${config.networking.hostName}.internal";
in
{
  options.services.pocket-id = {
    enable = mkEnableOption "Pocket ID passkey-only OIDC provider";

    dataVolume = mkOption {
      type = types.str;
      default = "pocket-id-data";
      description = "Docker named volume holding Pocket ID's SQLite database and WebAuthn credential store. A named volume lives on VM-internal storage (not virtiofs), which is what SQLite requires; see modules/pocket-id/design.md.";
    };

    keyDir = mkOption {
      type = types.str;
      # Realpath form (/private/var/...), not the /var symlink form: OrbStack
      # only treats a bind-mount source written as a resolved realpath as a
      # host share (virtiofs). The /var -> /private/var symlink form silently
      # mounts as a VM-internal overlay dir instead, so the container never
      # sees the host folder. See modules/pocket-id/design.md.
      default = "/private/var/lib/pocket-id";
      description = "Host directory holding the sops-provisioned encryption key file, bind-mounted read-only into the container.";
    };

    # OIDC clients and user groups registered on this Pocket ID instance.
    # Each service module declares the clients and groups it needs here;
    # scripts/pocket-id-register-clients.sh reconciles these against the
    # live Pocket ID via its admin API (see that script and
    # docs/oidc-setup.md). Single source of truth is this option tree.
    oidcClients = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Display name shown in Pocket ID and on the consent screen.";
          };

          clientId = mkOption {
            type = types.str;
            description = ''
              Fixed client ID. Pocket ID stores it verbatim (case-sensitive).
              For OpenCloud desktop/mobile this MUST match the hardcoded
              value in the app (OpenCloudDesktop / OpenCloudAndroid /
              OpenCloudIOS); for other clients any string is fine.
            '';
          };

          isPublic = mkOption {
            type = types.bool;
            default = false;
            description = "Public client: no client secret, PKCE required (Pocket ID forces PKCE on public clients regardless of pkceEnabled).";
          };

          pkceEnabled = mkOption {
            type = types.bool;
            default = false;
            description = "Require PKCE. Ignored (forced true) when isPublic is set.";
          };

          callbackURLs = mkOption {
            type = types.listOf types.str;
            description = "Allowed redirect URIs (OAuth redirect_uri allowlist).";
          };

          logoutCallbackURLs = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Allowed post-logout redirect URIs (end_session).";
          };

          allowedGroups = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Names of services.pocket-id.oidcGroups allowed to use this client. Non-empty enables group restriction (deny all other users).";
          };

          secretFile = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              Confidential clients only: repo-relative path to the sops
              secrets file holding the client secret (e.g.
              modules/forgejo/secrets.yaml). Written by
              scripts/pocket-id-register-clients.sh.
            '';
          };

          secretKey = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Confidential clients only: sops key name for the client secret (e.g. forgejo_oidc_client_secret).";
          };
        };
      });
      default = [ ];
      description = "OIDC clients to register on Pocket ID, declared by each service module.";
    };

    oidcGroups = mkOption {
      type = types.listOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Group name (used as the match key and for claim mapping).";
          };

          friendlyName = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable group name; falls back to name when empty.";
          };

          customClaims = mkOption {
            type = types.listOf (types.submodule {
              options = {
                key = mkOption { type = types.str; };
                value = mkOption { type = types.str; };
              };
            });
            default = [ ];
            description = "Custom claims applied to users in this group (e.g. opencloud_role -> opencloudAdmin).";
          };

          adminGroup = mkOption {
            type = types.bool;
            default = false;
            description = "If true, the user passed to scripts/pocket-id-register-clients.sh --admin-user is added to this group.";
          };
        };
      });
      default = [ ];
      description = "User groups to create on Pocket ID, declared by each service module.";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [{
      name = "Pocket ID";
      url = "https://auth.${domain}";
      descriptionJa = "パスキー認証プロバイダ (OIDC)";
      descriptionEn = "Passkey Authentication Provider (OIDC)";
      logoSvg = builtins.readFile ./pocket-id-logo.svg;
    }];

    environment.etc."newsyslog.d/pocket-id.conf".text = ''
      # logfilename            [owner:group]  mode  count  size  when  flags
      /var/log/pocket-id.log                  644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/pocket-id.caddy".text = ''
      https://auth.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:1411
      }
    '';

    sops.secrets.pocket_id_encryption_key = {
      sopsFile = ./secrets-${config.networking.hostName}.yaml;
    };

    launchd.daemons.pocket-id-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/pocket-id.log";
        StandardErrorPath = "/var/log/pocket-id.log";
      };
      script = ''
        until [ -S /var/run/docker.sock ]; do
          echo "Waiting for OrbStack socket..."
          sleep 5
        done

        export POCKET_ID_APP_URL="https://auth.${domain}"
        export POCKET_ID_KEY_FILE="${cfg.keyDir}/encryption_key"

        # cfg.keyDir is a realpath form (/private/var/...), which is what
        # OrbStack needs to treat a bind-mount source as a host share
        # (virtiofs) instead of a VM-internal overlay dir. The key file is a
        # single, small, read-only host file bind-mounted into the container;
        # the SQLite DB itself lives on the ${cfg.dataVolume} named volume
        # (VM-internal storage) and never touches virtiofs. See design.md.
        mkdir -p "${cfg.keyDir}"

        # Only actually rewrite the file when its content changed: this keeps
        # `--force-recreate` (below) from touching it on every ordinary
        # reboot, limiting churn here to first-ever bootstrap and actual sops
        # key rotations.
        if ! cmp -s "${config.sops.secrets.pocket_id_encryption_key.path}" \
          "$POCKET_ID_KEY_FILE" 2>/dev/null; then
          rm -rf "$POCKET_ID_KEY_FILE"
          cp "${config.sops.secrets.pocket_id_encryption_key.path}" \
            "$POCKET_ID_KEY_FILE" && \
            chmod 444 "$POCKET_ID_KEY_FILE"
        fi

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
