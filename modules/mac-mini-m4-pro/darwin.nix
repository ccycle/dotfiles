{ ... }:

{
  networking.hostName = "mac-mini-m4-pro";

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
  services.forgejo.pushMirrors = [
    {
      owner = "ccycle";
      repo = "dotfiles";
      remoteUrl = "https://github.com/ccycle/dotfiles.git";
    }
  ];
  services.forgejo.runnerEnable = true;
  services.forgejo.backupEnable = true;
  services.forgejo.branchProtections = [
    {
      owner = "ccycle";
      repo = "dotfiles";
      # Forgejo Actions reports commit-status contexts as
      # "<workflow name> / <job id> (<event>)" - confirmed against a live
      # instance via tests/e2e-forgejo (it observed "E2E / verify (push)"
      # for a workflow named "E2E" with job id "verify"; .forgejo/workflows
      # /verify.yaml has workflow name "Verify" and job id "verify", so this
      # follows the same pattern). Still worth a one-time check against the
      # real repo's Checks UI after the first live run, since a mismatched
      # context permanently blocks merges.
      statusCheckContexts = [ "Verify / verify (push)" ];
    }
  ];
  custom.lm-studio.enable = true;
  services.llm-server.enable = true;
  services.mtplx.enable = true;

  services.atticd.enable = true;
  services.staticReports.enable = true;

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
