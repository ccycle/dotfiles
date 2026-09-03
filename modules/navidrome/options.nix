{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.navidrome;
  composeFile = ./compose.yaml;
  waitForMount = import ../../utils/waitForMount.nix;
in
{
  options.services.navidrome = {
    enable = mkEnableOption "Navidrome music streaming server";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/navidrome/data";
      description = "Directory for Navidrome's application data (SQLite DB, cache).";
    };

    mountPoint = mkOption {
      type = types.str;
      default = "";
    };

    musicDir = mkOption {
      type = types.str;
      default = "";
      description = "Path to the music library on the external storage volume.";
    };

    port = mkOption {
      type = types.int;
      default = 4533;
      description = "Port Navidrome listens on inside the container (and on 127.0.0.1).";
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "Navidrome";
        url = "https://navidrome.${config.networking.hostName}.internal";
        descriptionJa = "音楽ストリーミングサーバー";
        descriptionEn = "Music Streaming Server";
        logoSvg = builtins.readFile ./navidrome-logo.svg;
      }
    ];

    environment.etc."newsyslog.d/navidrome.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/navidrome.log                  644   7      10240 *     GZ
    '';

    environment.etc."caddy/sites/navidrome.caddy".text = ''
      https://navidrome.${config.networking.hostName}.internal {
        import internal_tls
        forward_auth 127.0.0.1:1411 {
          uri /api/authz/forward-auth
          copy_headers X-Remote-User X-Remote-Groups X-Remote-Email
        }
        reverse_proxy 127.0.0.1:${toString cfg.port} {
          header_up X-Remote-User {http.miss.X-Remote-User}
          header_up X-Remote-Groups {http.miss.X-Remote-Groups}
          header_up X-Remote-Email {http.miss.X-Remote-Email}
        }
      }
    '';

    launchd.daemons.navidrome-compose = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/navidrome.log";
        StandardErrorPath = "/var/log/navidrome.log";
      };
      script = ''
        ${optionalString (cfg.mountPoint != "") (waitForMount cfg.mountPoint)}

        until ${pkgs.docker}/bin/docker info >/dev/null 2>&1; do
          echo "Waiting for Docker to be ready..."
          sleep 5
        done

        export NAVIDROME_DATA_DIR="${cfg.dataDir}"
        export NAVIDROME_MUSIC_DIR="${cfg.musicDir}"
        export NAVIDROME_PORT="${toString cfg.port}"

        mkdir -p "$NAVIDROME_DATA_DIR"

        exec ${pkgs.docker-compose}/bin/docker-compose \
          -f ${composeFile} \
          up --no-build --force-recreate
      '';
    };
  };
}
