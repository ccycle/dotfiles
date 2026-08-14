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
      # Realpath form (/private/var/...), not the /var symlink form: OrbStack
      # only treats a bind-mount source written as a resolved realpath as a
      # host share (virtiofs). The /var -> /private/var symlink form silently
      # mounts as a VM-internal overlay dir instead, so the container never
      # sees the host folder. See modules/pocket-id/design.md.
      default = "/private/var/lib/pocket-id/data";
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

        # cfg.dataDir is a realpath form (/private/var/...), which is what
        # OrbStack needs to treat it as a host share (virtiofs) instead of a
        # VM-internal overlay dir. See design.md.
        mkdir -p "$POCKET_ID_DATA_DIR"

        # The container runs as uid 1000, which OrbStack maps to the host
        # user, so it must be able to write the SQLite DB into dataDir.
        # Without this the container logs "unable to open database file (14)"
        # as soon as the bind-mount path is corrected. Follows the same
        # pattern as modules/static-reports.
        chown ${config.system.primaryUser} "$POCKET_ID_DATA_DIR"

        # The encryption key (and later the SQLite DB) lives inside the one
        # directory that is an actual host bind mount, rather than as its own
        # separate bind mount source: OrbStack auto-vivifies a standalone
        # bind-mount source as an empty VM-internal directory unless it is
        # written in resolved realpath form, and a file inside an already
        # mounted directory is always visible. See design.md.
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
