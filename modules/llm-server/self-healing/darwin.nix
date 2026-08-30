{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.selfHealing;
in
{
  imports = [
    ./options.nix
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.llm-server.enable;
        message = "services.selfHealing requires services.llm-server.enable = true — remediation decisions are made by the local LLM.";
      }
    ];

    environment.etc."newsyslog.d/self-healing.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/self-healing.log              644   7      10240 *     GZ
    '';

    launchd.daemons.self-healing = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        # Daily poll (see design.md for why alert-detection cadence isn't
        # severity-differentiated in this first iteration).
        StartInterval = 86400;
        StandardOutPath = "/var/log/self-healing.log";
        StandardErrorPath = "/var/log/self-healing.log";
      };
      script = ''
        export PATH="${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.docker-compose}/bin:${pkgs.coreutils}/bin:$PATH"
        export PROMETHEUS_URL="http://127.0.0.1:9090"
        export LOKI_URL="http://127.0.0.1:3100"
        export LLM_SERVER_URL="http://127.0.0.1:${toString config.services.llm-server.port}"
        export MODEL_ID="${cfg.model}"
        export SELF_HEALING_MODE="${cfg.mode}"
        export TARGET_PROJECTS="${concatStringsSep " " cfg.targetProjects}"

        exec ${pkgs.bash}/bin/bash ${./scripts/self-healing-daemon.sh}
      '';
    };
  };
}
