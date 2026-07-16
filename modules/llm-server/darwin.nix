{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.llm-server.modelsDir = lib.mkIf hasVol (lib.mkDefault "${vol}/llm-server/models");
  services.llm-server.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);
}
