{ lib, ... }:

with lib;

{
  options.services.selfHealing = {
    enable = mkEnableOption "Self-healing monitoring daemon";

    mode = mkOption {
      type = types.enum [
        "log-only"
        "auto-remediate"
      ];
      default = "log-only";
      description = ''
        "log-only": poll for firing alerts, ask the local LLM what it
        would do, and log the decision without executing it. Review the
        Self-Healing Grafana dashboard before switching.
        "auto-remediate": execute the LLM's chosen action (subject to the
        fixed action allow-list) and verify it after a health-check wait.
      '';
    };

    targetProjects = mkOption {
      type = types.listOf types.str;
      default = [
        "immich"
        "opencloud"
        "forgejo"
        "monitoring"
      ];
      description = ''
        docker compose project names in scope for automated remediation.
        Alerts for projects outside this list are logged as
        skipped-out-of-scope without calling the LLM. GitLab is
        intentionally excluded by default — see design.md.
      '';
    };

    model = mkOption {
      type = types.str;
      default = "ornith-ai/Ornith-1.5-35B-A3B-GGUF";
      description = "Model ID from modules/llm-server/catalog.json used for remediation decisions.";
    };
  };
}
