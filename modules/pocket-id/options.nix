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
      sopsFile = ./secrets.yaml;
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
        export POCKET_ID_ENCRYPTION_KEY_FILE="/tmp/pocket_id_encryption_key"

        mkdir -p "$POCKET_ID_DATA_DIR"

        # Copy encryption key to /tmp/ so OrbStack's Docker VM can reach it
        # (/run/ is not shared with the Linux VM, but /tmp/ is).
        cp "${config.sops.secrets.pocket_id_encryption_key.path}" \
          "$POCKET_ID_ENCRYPTION_KEY_FILE" && \
          chmod 444 "$POCKET_ID_ENCRYPTION_KEY_FILE"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
