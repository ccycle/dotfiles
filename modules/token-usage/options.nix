{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.tokenUsage;
  pricesFile = ./prices.json;
  aggregateScript = ./aggregate.py;
in
{
  options.services.tokenUsage = {
    enable = mkEnableOption "Daily Claude Code / opencode token-usage & cost aggregation into this host's node-exporter textfile dir";

    textfileDir = mkOption {
      type = types.str;
      default = "/var/lib/node-exporter-textfile";
      description = "node-exporter textfile collector directory on this host (see modules/monitoring/options.nix's nodeExporterTextfileDir).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.monitoring.enable;
        message = "services.tokenUsage writes into the local node-exporter textfile dir, so it requires services.monitoring.enable on the same host.";
      }
    ];

    launchd.user.agents.token-usage = {
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 86400;
        StandardOutPath = "/var/tmp/token-usage.log";
        StandardErrorPath = "/var/tmp/token-usage.log";
      };
      script = ''
        set -euo pipefail
        ${pkgs.python3}/bin/python3 ${aggregateScript} \
          --prices ${pricesFile} \
          --claude-projects-dir "$HOME/.claude/projects" \
          --opencode-db "$HOME/.local/share/opencode/opencode.db" \
          --out "${cfg.textfileDir}/token_usage.prom"
      '';
    };
  };
}
