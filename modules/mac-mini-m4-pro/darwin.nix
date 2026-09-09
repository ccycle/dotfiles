{ ... }:

{
  networking.hostName = "mac-mini-m4-pro";

  # No local GUI session ever available (see modules/pinentry/darwin.nix).
  custom.pinentry.headless = true;

  services.altserver.enable = true;
  services.tailscale.splitDns.enable = true;
  services.opencloud.enable = true;
  # Self-built image with services/unzip (server-side extraction) and related
  # fixes not yet upstream - see modules/opencloud/build-backend-image.sh.
  services.opencloud.image = "opencloud-unzip-server:latest";
  services.caddy.enable = true;
  custom.dnsmasq.enable = true;
  services.immich.enable = true;
  services.monitoring.enable = true;
  # Dormant: superseded by Forgejo (modules/forgejo) for git hosting. Kept
  # in place rather than deleted until the Forgejo evaluation gate passes -
  # CI running on real hardware, branch protection active, and backup/
  # restore proven, all on dotfiles - at which point this module is
  # removed. See modules/forgejo/design.md for the staged migration plan.
  services.gitlab.enable = false;
  services.pocket-id.enable = true;
  services.forgejo.enable = true;
  services.navidrome.enable = true;
  services.forgejo.pushMirrors = [
    {
      owner = "ccycle";
      repo = "dotfiles";
      remoteUrl = "https://github.com/ccycle/dotfiles.git";
    }
  ];
  services.forgejo.runnerEnable = true;
  services.forgejo.backupEnable = true;
  # Branch protection is managed via the Forgejo GUI (repo Settings >
  # Branches), not services.forgejo.branchProtections - required check
  # contexts live with the workflows that report them.
  custom.lm-studio.enable = true;
  services.llm-server.enable = true;
  services.opencode-web.enable = true;
  services.pi-web.enable = true;
  services.mtplx.enable = true;
  services.mlx-server.enable = true;

  services.atticd.enable = true;
  services.staticReports.enable = true;

  # This host is both where Claude Code / opencode sessions actually run
  # (via Herdr worktrees over SSH) and where its own monitoring stack
  # lives, so the daily push target is this host's own tailnet name -
  # see modules/token-usage/design.md.
  services.tokenUsage.enable = true;
  services.tokenUsage.remoteHost = "mac-mini-m4-pro.internal";

  # log-only (the default) - decisions get logged and reviewable on the
  # Self-Healing Grafana dashboard, nothing executes yet. propose-fix-pr
  # stays inert too (fixAllowList/fixRepoUrl/fixRepo left at their empty
  # defaults) - deliberately not turned on here; granting an LLM the
  # ability to open PRs against this repo is a separate decision for a
  # human to make explicitly, not a side effect of enabling detection.
  services.selfHealing.enable = true;

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
