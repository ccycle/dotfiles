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
        propose-fix-pr is the one action whose "verification" is human
        review + CI, not an automated re-check — see design.md.
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

    fixAllowList = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Path prefixes (relative to the repo root) the propose-fix-pr
        action is permitted to touch. Empty (the default) disables
        propose-fix-pr entirely — a host must opt in explicitly, since
        this governs what an autonomous coding run may modify. Any
        secrets.yaml / secrets-*.yaml file is rejected unconditionally,
        regardless of this list.
      '';
    };

    fixModel = mkOption {
      type = types.str;
      default = "llamaswap/qwen/qwen3.6-35b-a3b";
      description = "opencode model (provider/id) used to draft a propose-fix-pr change. A local model, matching this module's no-external-dependency design.";
    };

    fixWorkDir = mkOption {
      type = types.str;
      default = "/var/lib/self-healing/dotfiles-workdir";
      description = "Local working copy propose-fix-pr clones/reuses to draft its change.";
    };

    fixRepoUrl = mkOption {
      type = types.str;
      default = "";
      description = "Clone URL for the repo propose-fix-pr drafts changes in. Empty disables the action (see fixAllowList).";
    };

    fixRepo = mkOption {
      type = types.str;
      default = "";
      description = "owner/repo shorthand passed to `fj pr create --repo`.";
    };

    fixBaseBranch = mkOption {
      type = types.str;
      default = "main";
      description = "Base branch propose-fix-pr branches from and targets.";
    };

    webhookPort = mkOption {
      type = types.port;
      default = 9096;
      description = "Loopback port the Alertmanager webhook listener binds to (see modules/monitoring/alertmanager.yml).";
    };
  };
}
