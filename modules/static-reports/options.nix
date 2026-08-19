{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.staticReports;
  domain = "${config.networking.hostName}.internal";
in
{
  options.services.staticReports = {
    enable = mkEnableOption "Tailscale-reachable static file host for reports/artifacts (e2e test reports, coverage, etc.)";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/static-reports";
      description = ''
        Directory served at https://reports.<hostname>.internal. Anything
        placed in a subdirectory here (e.g. by a worktree's own tooling)
        becomes browsable and downloadable over the tailnet. No app-level
        auth — reachability is gated by the existing Tailscale ACL only,
        matching every other internal service.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.caddy.portalEntries = [{
      name = "Reports";
      url = "https://reports.${domain}";
      descriptionJa = "静的レポート・成果物の閲覧 (テスト結果など)";
      descriptionEn = "Browse static reports/artifacts (test results, etc.)";
      logoSvg = builtins.readFile ./reports-logo.svg;
    }];

    environment.etc."caddy/sites/static-reports.caddy".text = ''
      https://reports.${domain} {
        import internal_tls
        root * ${cfg.dataDir}
        file_server browse
      }
    '';

    # User-writable, not root-owned: populated by plain user scripts
    # (e.g. .agents/skills/e2e-test-opencloud/scripts/run.sh) with no
    # launchd/root daemon of its own — Caddy only reads from it.
    system.activationScripts.postActivation.text = ''
      mkdir -p ${cfg.dataDir}
      chown ${config.system.primaryUser} ${cfg.dataDir}
    '';
  };
}
