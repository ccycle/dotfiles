{ config, lib, ... }:

let
  vol = config.custom.storage.volumeRoot;
  hasVol = vol != "";
in
{
  imports = [
    ./options.nix
  ];

  services.monitoring.dataDir = lib.mkIf hasVol (lib.mkDefault "${vol}/monitoring");
  services.monitoring.mountPoint = lib.mkIf hasVol (lib.mkDefault vol);

  # Collect GitLab's file logs (rails, sidekiq, gitaly, ...) into Loki; they
  # never reach the container's stdout.
  services.monitoring.gitlabLogsDir = lib.mkIf config.services.gitlab.enable (
    lib.mkDefault config.services.gitlab.logsDir
  );
}
