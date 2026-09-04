{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

with lib;

let
  cfg = config.services.atticd;
  atticPkg = inputs.attic.packages.${pkgs.stdenv.hostPlatform.system}.default;
  format = pkgs.formats.toml { };

  atticExporter = pkgs.writeShellApplication {
    name = "attic-exporter";
    runtimeInputs = [
      pkgs.python3
      pkgs.sqlite
    ];
    text = ''
      exec ${pkgs.python3}/bin/python3 ${./attic-exporter.py} "$@"
    '';
  };
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

  config = mkMerge [
    (mkIf cfg.enable {
      services.atticd.settings = mkDefault {
        listen = "127.0.0.1:8081";
        database.url = "sqlite:///var/lib/atticd/server.db?mode=rwc";
        storage = {
          type = "local";
          path = "/var/lib/atticd/storage";
        };
        chunking = {
          nar-size-threshold = 64 * 1024;
          # Larger than Attic's own upstream default (16K/64K/256K). Some
          # cached closures include multi-hundred-MB macOS .app bundles
          # (e.g. orbstack, ~680MB), which at the default chunk size split
          # into 10000+ chunks per NAR - see modules/attic/design.md for the
          # "Bad NAR Hash or Size" push failure this was raised to mitigate.
          min-size = 256 * 1024;
          avg-size = 1024 * 1024;
          max-size = 4 * 1024 * 1024;
        };
        # Age out cache objects not accessed within the retention period.
        # last_accessed_at is bumped only on nar downloads (not on pushes),
        # so the cache stays bounded to recently-pulled content.
        "garbage-collection" = {
          interval = "6 hours";
          "default-retention-period" = "30 days";
        };
      };

      sops.secrets.atticd-jwt-secret = {
        sopsFile = ./secrets.yaml;
      };

      environment.etc."atticd/server.toml".source = format.generate "server.toml" cfg.settings;

      launchd.daemons.atticd = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/log/atticd.log";
          StandardErrorPath = "/var/log/atticd.log";
        };
        script = ''
          mkdir -p /var/lib/atticd/storage
          export ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64="$(
            cat ${config.sops.secrets.atticd-jwt-secret.path}
          )"
          exec ${atticPkg}/bin/atticd \
            -f /etc/atticd/server.toml \
            --mode monolithic
        '';
      };

      launchd.daemons.attic-exporter = {
        serviceConfig = {
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "/var/log/attic-exporter.log";
          StandardErrorPath = "/var/log/attic-exporter.log";
        };
        script = ''
          exec ${atticExporter}/bin/attic-exporter \
            --db /var/lib/atticd/server.db \
            --storage /var/lib/atticd/storage \
            --port 9201
        '';
      };
    })
  ];
}
