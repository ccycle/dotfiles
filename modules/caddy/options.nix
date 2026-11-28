{ lib, ... }:

{
  options.services.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";

    portalEntries = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption { type = lib.types.str; };
            url = lib.mkOption { type = lib.types.str; };
            descriptionJa = lib.mkOption { type = lib.types.str; };
            descriptionEn = lib.mkOption { type = lib.types.str; };
            logoSvg = lib.mkOption { type = lib.types.str; };
            alwaysOn = lib.mkOption {
              type = lib.types.bool;
              description = "Whether the service is expected to answer at all times. Only always-on entries get a reachability probe and EndpointDown alert (modules/monitoring); set false for services started on demand.";
            };
          };
        }
      );
      default = [ ];
    };
  };
}
