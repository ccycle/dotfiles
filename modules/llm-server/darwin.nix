{ config, lib, ... }:

with lib;

let
  warnIfVolumeMissing = import ../../utils/warnIfVolumeMissing.nix;
  vol = warnIfVolumeMissing lib "llm-server" (config.custom.storage.volumes.llm-server or "");
  cfg = config.services.llm-server;
in
{
  imports = [
    ./options.nix
    ./self-healing/darwin.nix
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = vol != "";
        message = "custom.storage.volumes.llm-server must be set. Run: .agents/skills/setup-local-storage/scripts/setup-local-storage.sh llm-server=~/.ollama/models";
      }
    ];

    # No subpath appended: vol points directly at Ollama's own default
    # model store (~/.ollama/models), matching upstream convention instead
    # of inventing a new directory layout.
    services.llm-server.modelsDir = mkDefault vol;
    services.llm-server.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
  };
}
