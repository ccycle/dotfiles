{ lib, ... }:

{
  options.services.ntfy = {
    enable = lib.mkEnableOption "ntfy push notification server for Alertmanager alerts";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2586;
    };
  };
}
