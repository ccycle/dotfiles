{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.altserver;
in
{
  options.services.altserver = {
    enable = mkEnableOption "AltServer for free-tier iOS sideload signing (home Wi-Fi only)";
  };

  config = mkIf cfg.enable {
    # Exposes the `altserver` CLI wrapper on PATH for build-and-sign.sh
    # (the LaunchAgent below references the same package directly, not PATH).
    environment.systemPackages = [ pkgs.brewCasks.altserver ];

    launchd.user.agents.altserver = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/altserver.log";
        StandardErrorPath = "/var/tmp/altserver.log";
      };
      script = ''
        exec ${pkgs.brewCasks.altserver}/bin/altserver
      '';
    };
  };
}
