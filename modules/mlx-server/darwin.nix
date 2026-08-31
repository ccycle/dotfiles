{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.mlx-server;
  mlxEnv = pkgs.python3.withPackages (ps: with ps; [ mlx-lm mlx ]);
in
{
  imports = [ ./options.nix ];

  config = mkIf cfg.enable {
    launchd.user.agents.mlx-server = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/tmp/mlx-server.log";
        StandardErrorPath = "/var/tmp/mlx-server.log";
      };
      script = ''
        set -euo pipefail

        mkdir -p "${cfg.modelsDir}"

        exec ${mlxEnv}/bin/python3 -m mlx_lm server \
          --model "${cfg.defaultModel}" \
          --host 127.0.0.1 \
          --port ${toString cfg.port}
      '';
    };
  };
}
