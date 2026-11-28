{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.ntfy;
  baseUrl = "https://ntfy.${config.networking.hostName}.internal";
  stateDir = "/var/lib/ntfy";
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "ntfy";
        url = baseUrl;
        descriptionJa = "アラートのプッシュ通知";
        descriptionEn = "Push notifications for alerts";
        logoSvg = builtins.readFile ./ntfy-logo.svg;
        alwaysOn = true;
      }
    ];

    environment.etc."caddy/sites/ntfy.caddy".text = ''
      http://ntfy.${config.networking.hostName}.internal, ${baseUrl} {
        import internal_tls
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';

    launchd.daemons.ntfy = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/ntfy.log";
        StandardErrorPath = "/var/log/ntfy.log";
      };
      script = ''
        mkdir -p ${stateDir}
        exec ${pkgs.ntfy-sh}/bin/ntfy serve \
          --listen-http 127.0.0.1:${toString cfg.port} \
          --base-url ${baseUrl} \
          --behind-proxy \
          --cache-file ${stateDir}/cache.db \
          --upstream-base-url https://ntfy.sh
      '';
    };
  };
}
