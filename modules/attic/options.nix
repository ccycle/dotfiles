{ config, lib, pkgs, inputs, ... }:

with lib;

let
  cfg = config.services.atticd;
  watchStoreCfg = config.services.attic-watch-store;
  atticPkg = inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.default;
  format = pkgs.formats.toml { };
in
{
  options.services.atticd = {
    enable = mkEnableOption "Attic binary cache server";

    settings = mkOption {
      type = format.type;
      default = { };
      description = "Atticd server configuration (server.toml). See https://docs.attic.rs.";
    };
  };

  options.services.attic-watch-store = {
    enable = mkEnableOption "Attic watch-store auto-push";

    cacheName = mkOption {
      type = types.str;
      description = "Cache name on the attic server to push to.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      services.atticd.settings = mkDefault {
        listen = "127.0.0.1:8081";
        database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";
        storage = {
          type = "local";
          path = "/var/lib/atticd/storage";
        };
      };

      sops.secrets.atticd-jwt-secret = {
        sopsFile = ./secrets.yaml;
      };

      environment.etc."atticd/server.toml".source =
        format.generate "server.toml" cfg.settings;

      launchd.daemons.atticd = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/log/atticd.log";
          StandardErrorPath = "/var/log/atticd.log";
        };
        script = ''
          export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="$(
            cat ${config.sops.secrets.atticd-jwt-secret.path}
          )"
          exec ${atticPkg}/bin/atticd \
            -f /etc/atticd/server.toml \
            --mode monolithic
        '';
      };
    })

    (mkIf watchStoreCfg.enable {
      sops.secrets.attic-watch-token = {
        sopsFile = ./secrets.yaml;
      };

      launchd.user.agents.attic-watch-store = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/tmp/attic-watch-store.log";
          StandardErrorPath = "/var/tmp/attic-watch-store.log";
        };
        script = ''
          export ATTIC_TOKEN="$(cat ${config.sops.secrets.attic-watch-token.path})"
          exec ${atticPkg}/bin/attic watch-store ${watchStoreCfg.cacheName}
        '';
      };
    })
  ];
}
