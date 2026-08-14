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
        export POCKET_ID_ENCRYPTION_KEY_FILE="${builtins.dirOf cfg.dataDir}/pocket_id_encryption_key"

        mkdir -p "$POCKET_ID_DATA_DIR"

        # Copy the encryption key next to $POCKET_ID_DATA_DIR (under /var/lib/,
        # already proven reachable from OrbStack's Docker VM by that same data
        # dir) rather than /tmp/: the compose service has `restart: always`, so
        # Docker can bring the container back up on its own whenever the Docker
        # daemon restarts, independently of and before this launchd script gets
        # a chance to re-run. /tmp/ does not survive a host reboot, so that
        # independent restart could race ahead of this cp and mount an empty
        # bind-mount source. A path under /var/lib/ persists across reboots, so
        # once written once, it's always there for that race to land on.
        #
        # Only actually rewrite the file when its content changed. OrbStack's
        # Docker VM has a real, currently-unresolved virtiofs bind-mount
        # staleness bug (orbstack/orbstack#1026, #1287, #1240): a file that
        # was *just* written on the host can lose the race with the VM's view
        # syncing up, and get permanently auto-vivified as an empty directory
        # for that container's lifetime - retrying or waiting did not recover
        # it in testing, only a full `docker compose down` + recreate did. A
        # file that has sat here unchanged since a prior successful boot is
        # already correctly synced, so skipping the rewrite when nothing
        # changed keeps `--force-recreate` (below) from re-running this race
        # on every ordinary reboot - it's only still live for the first-ever
        # bootstrap and actual sops key rotations.
        if ! cmp -s "${config.sops.secrets.pocket_id_encryption_key.path}" \
          "$POCKET_ID_ENCRYPTION_KEY_FILE" 2>/dev/null; then
          # Remove any stale path first: if a prior run raced with
          # docker-compose and lost, Docker auto-vivifies the bind-mount
          # source as a directory, and cp into an existing directory copies
          # *into* it instead of replacing it, which would wedge the
          # container in a permanent restart loop.
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
