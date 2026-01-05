{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.cachix-watch-store;

  startScript = pkgs.writeShellScriptBin "start-cachix-watch-store" ''
    SERVICE_NAME="org.nixos.cachix-watch-store"
    echo "Starting $SERVICE_NAME..."
    launchctl bootstrap gui/$(id -u) "/Library/LaunchAgents/$SERVICE_NAME.plist"
    echo "$SERVICE_NAME started."
  '';

  stopScript = pkgs.writeShellScriptBin "stop-cachix-watch-store" ''
    SERVICE_NAME="org.nixos.cachix-watch-store"
    echo "Stopping $SERVICE_NAME..."
    launchctl bootout gui/$(id -u) "gui/$(id -u)/$SERVICE_NAME"
    echo "$SERVICE_NAME stopped."
  '';
in
{
  options.services.cachix-watch-store = {
    enable = mkEnableOption "cachix watch-store service";

    cacheName = mkOption {
      type = types.str;
      description = "The name of the cachix cache to push to.";
    };

    cachixTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to the file containing the Cachix authentication token.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ startScript stopScript ];

    launchd.user.agents.cachix-watch-store = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/cachix-watch-store.log";
        StandardErrorPath = "/var/tmp/cachix-watch-store.log";
      };

      script = ''
        ${optionalString (cfg.cachixTokenFile != null) ''
          export CACHIX_AUTH_TOKEN="$(cat ${cfg.cachixTokenFile})"
        ''}
        exec ${pkgs.cachix}/bin/cachix watch-store ${cfg.cacheName}
      '';
    };
  };
}
