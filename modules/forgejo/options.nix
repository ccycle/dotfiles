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

    mountPoint = mkOption {
      type = types.str;
      default = "";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [{
      name = "Forgejo";
      url = "https://forgejo.${config.networking.hostName}.internal";
      descriptionJa = "軽量 Git フォージ";
      descriptionEn = "Lightweight Git Forge";
      logoSvg = ''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 212 212"><g transform="translate(6,6)"><path d="M58 168v-98a50 50 0 0 1 50-50h20" fill="none" stroke="#ff6600" stroke-width="25"/><path d="M58 168v-30a50 50 0 0 1 50-50h20" fill="none" stroke="#d40000" stroke-width="25"/><circle cx="142" cy="20" r="18" fill="none" stroke="#ff6600" stroke-width="15"/><circle cx="142" cy="88" r="18" fill="none" stroke="#d40000" stroke-width="15"/><circle cx="58" cy="180" r="18" fill="none" stroke="#d40000" stroke-width="15"/></g></svg>'';
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

        mkdir -p "$FORGEJO_DATA_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
