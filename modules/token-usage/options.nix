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
    enable = mkEnableOption "Daily Claude Code / opencode token-usage & cost aggregation, pushed over the tailnet to a node-exporter textfile dir";

    remoteHost = mkOption {
      type = types.str;
      description = ''
        Tailnet host (its .internal MagicDNS name, e.g.
        mac-mini-m4-pro.internal) whose node-exporter textfile collector
        directory receives the generated token_usage.prom over SSH/scp.
        May be this same host - the mechanism is the same either way.
      '';
    };

    remoteTextfileDir = mkOption {
      type = types.str;
      default = "/var/lib/node-exporter-textfile";
      description = "Remote node-exporter textfile collector directory (see modules/monitoring/options.nix's nodeExporterTextfileDir).";
    };
  };

  config = mkIf cfg.enable {
    # User-level LaunchAgent (not a root daemon): it only ever needs to
    # read this user's own ~/.claude and ~/.local/share/opencode data and
    # push over this user's own SSH identity - no elevated privilege
    # required, unlike the node-exporter/textfile-collector daemons in
    # modules/monitoring, which touch root-owned system paths.
    launchd.user.agents.token-usage = {
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 86400;
        StandardOutPath = "/var/tmp/token-usage.log";
        StandardErrorPath = "/var/tmp/token-usage.log";
      };
      script = ''
        OUT="$(${pkgs.coreutils}/bin/mktemp -t token-usage-XXXXXX).prom"
        ${pkgs.python3}/bin/python3 ${aggregateScript} \
          --prices ${pricesFile} \
          --claude-projects-dir "$HOME/.claude/projects" \
          --opencode-db "$HOME/.local/share/opencode/opencode.db" \
          --out "$OUT"

        # accept-new (not off/no): trusts an unseen host key on first
        # contact, like any automated tool must to run non-interactively,
        # but still fails closed against a key that later changes.
        SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
        ${pkgs.openssh}/bin/scp $SSH_OPTS \
          "$OUT" "${cfg.remoteHost}:${cfg.remoteTextfileDir}/token_usage.prom.tmp"
        ${pkgs.openssh}/bin/ssh $SSH_OPTS "${cfg.remoteHost}" \
          "mv '${cfg.remoteTextfileDir}/token_usage.prom.tmp' '${cfg.remoteTextfileDir}/token_usage.prom'"
        ${pkgs.coreutils}/bin/rm -f "$OUT"
      '';
    };
  };
}
