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

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/pocket-id/data";
      description = "Directory for Pocket ID's SQLite database and WebAuthn credential store.";
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
        export POCKET_ID_DATA_DIR="${cfg.dataDir}"
        export POCKET_ID_ENCRYPTION_KEY_FILE="${cfg.dataDir}/encryption_key"

        mkdir -p "$POCKET_ID_DATA_DIR"

        # Written inside $POCKET_ID_DATA_DIR itself (see compose.yaml's
        # ENCRYPTION_KEY_FILE), not as its own separate bind mount: OrbStack's
        # Docker VM reliably auto-vivified a brand-new, standalone bind-mount
        # source as an empty directory instead of the real file underneath
        # it, regardless of path or filename - but a file appearing inside a
        # directory that's already an active bind mount (this one) has been
        # reliably visible all along. See design.md for the fuller story.
        #
        # Only actually rewrite the file when its content changed: this keeps
        # `--force-recreate` (below) from touching it on every ordinary
        # reboot, limiting churn here to first-ever bootstrap and actual sops
        # key rotations.
        if ! cmp -s "${config.sops.secrets.pocket_id_encryption_key.path}" \
          "$POCKET_ID_ENCRYPTION_KEY_FILE" 2>/dev/null; then
          rm -rf "$POCKET_ID_ENCRYPTION_KEY_FILE"
          cp "${config.sops.secrets.pocket_id_encryption_key.path}" \
            "$POCKET_ID_ENCRYPTION_KEY_FILE" && \
            chmod 444 "$POCKET_ID_ENCRYPTION_KEY_FILE"
        fi

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
