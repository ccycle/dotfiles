{ config, lib, ... }:

with lib;

let
  vol = config.custom.storage.volumeRoot;
  cfg = config.services.llm-server;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [{
      assertion = vol != "";
      message = "custom.storage.volumeRoot must be set for llm-server. Run: scripts/setup-local-storage.sh /Volumes/<YOUR_DRIVE>";
    }];

    services.llm-server.modelsDir = mkDefault "${vol}/llm-server/models";
    services.llm-server.mountPoint = mkDefault vol;
  };
}
