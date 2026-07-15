{ lib, ... }:

{
  options.custom.lm-studio = {
    enable = lib.mkEnableOption "LM Studio";
    server.enable = lib.mkEnableOption "LM Studio local API server (launchd agent + Caddy vhost)";
  };
}
