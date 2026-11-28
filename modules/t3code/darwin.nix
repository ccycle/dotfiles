{ config, lib, ... }:

with lib;

let
  cfg = config.services.t3code;
  domain = "${config.networking.hostName}.internal";
in
{
  options.services.t3code = {
    enable = mkEnableOption "Caddy site exposing the T3 Code web UI on the tailnet";

    port = mkOption {
      type = types.port;
      description = ''
        Loopback port of the T3 Code server.
        The server itself is the imperatively installed `t3` background service
        (see home.nix), not a Nix-managed daemon, so this must match the port
        `t3 up` configured (`origin` in ~/.t3/userdata/server-runtime.json).
      '';
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [
      {
        name = "T3 Code";
        url = "https://t3.${domain}";
        descriptionJa = "コーディングエージェント GUI";
        descriptionEn = "Coding agent GUI";
        logoSvg = builtins.readFile ./t3code-logo.svg;
        alwaysOn = true;
      }
    ];

    # No oauth2-proxy in front, unlike opencode-web: T3 enforces its own
    # pairing-based auth on proxied requests (unauthenticated API calls via
    # forwarded headers get 401 missing_credential, not loopback trust).
    environment.etc."caddy/sites/t3code.caddy".text = ''
      http://t3.${domain}, https://t3.${domain} {
        import internal_tls
        reverse_proxy 127.0.0.1:${toString cfg.port}
      }
    '';
  };
}
