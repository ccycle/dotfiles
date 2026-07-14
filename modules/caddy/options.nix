{ lib, ... }:

{
  options.services.caddy = {
    enable = lib.mkEnableOption "Caddy reverse proxy";
  };
}
