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
