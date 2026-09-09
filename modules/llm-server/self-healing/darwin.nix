{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.selfHealing;
  # Matches modules/monitoring/options.nix's nodeExporterTextfileDir — not
  # shared as an option, so kept in sync by convention like every other
  # cross-module literal in this repo (e.g. modules/token-usage's default).
  nodeExporterTextfileDir = "/var/lib/node-exporter-textfile";
  daemonScript = ./scripts/self-healing-daemon.sh;
  webhookListenerScript = ./scripts/webhook-listener.py;
  proposeFixScript = ./scripts/propose-fix.sh;
  # opencode/fj (forgejo-cli) come from this user's own home-manager
  # profile, not a re-vendored Nix derivation — this daemon now runs as
  # that user (see the launchd.user.agents note below), so its normal
  # installed tools are already the right ones: opencode's config
  # (~/.config/opencode/opencode.json, see modules/opencode/home.nix)
  # already points at the local llamaswap provider, and git/fj already
  # have this user's own Forgejo credentials.
  userBin = "/etc/profiles/per-user/mfuruki/bin";
  sharedPath = "${userBin}:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.docker-compose}/bin:${pkgs.coreutils}/bin:${pkgs.git}/bin:$PATH";
  sharedEnv = ''
    export PATH="${sharedPath}"
    export PROMETHEUS_URL="http://127.0.0.1:9090"
    export LOKI_URL="http://127.0.0.1:3100"
    export LLM_SERVER_URL="http://127.0.0.1:${toString config.services.llm-server.port}"
    export MODEL_ID="${cfg.model}"
    export SELF_HEALING_MODE="${cfg.mode}"
    export TARGET_PROJECTS="${concatStringsSep " " cfg.targetProjects}"
    export NODE_EXPORTER_TEXTFILE_DIR="${nodeExporterTextfileDir}"
    export PROPOSE_FIX_SCRIPT="${proposeFixScript}"
    export FIX_WORKDIR="${cfg.fixWorkDir}"
    export FIX_REPO_URL="${cfg.fixRepoUrl}"
    export FIX_REPO="${cfg.fixRepo}"
    export FIX_BASE_BRANCH="${cfg.fixBaseBranch}"
    export FIX_ALLOW_LIST="${concatStringsSep " " cfg.fixAllowList}"
    export FIX_MODEL="${cfg.fixModel}"
  '';
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
      {
        assertion = config.services.monitoring.enable;
        message = "services.selfHealing requires services.monitoring.enable = true — it reads Prometheus/Loki and is woken by monitoring's Alertmanager webhook.";
      }
    ];

    environment.etc."newsyslog.d/self-healing.conf".text = ''
      # logfilename          [owner:group]  mode  count  size  when  flags
      /var/log/self-healing.log              644   7      10240 *     GZ
    '';

    # User agents, not root daemons (a change from this module's original
    # shape): propose-fix-pr needs this user's opencode config and git/fj
    # credentials, which only exist in their own home directory context —
    # see design.md. docker-compose itself works fine per-user under
    # OrbStack, unlike Docker Desktop on Linux, so nothing else needed root
    # either.
    launchd.user.agents.self-healing = {
      serviceConfig = {
        RunAtLoad = true;
        # Slow backstop only now — the Alertmanager webhook below is the
        # primary, fast-detection trigger (see design.md and
        # prometheus-rules.yml's SelfHealingHeartbeatMissing).
        StartInterval = 86400;
        StandardOutPath = "/var/log/self-healing.log";
        StandardErrorPath = "/var/log/self-healing.log";
      };
      script = ''
        ${sharedEnv}
        exec ${pkgs.bash}/bin/bash ${daemonScript}
      '';
    };

    launchd.user.agents.self-healing-webhook = {
      serviceConfig = {
        KeepAlive = true;
        RunAtLoad = true;
        StandardOutPath = "/var/log/self-healing-webhook.log";
        StandardErrorPath = "/var/log/self-healing-webhook.log";
      };
      script = ''
        ${sharedEnv}
        exec ${pkgs.python3}/bin/python3 ${webhookListenerScript} ${daemonScript} ${toString cfg.webhookPort}
      '';
    };
  };
}
