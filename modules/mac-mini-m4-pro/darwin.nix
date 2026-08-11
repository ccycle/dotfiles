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
  services.gitlab.enable = false;
  services.pocket-id.enable = true;
  services.forgejo.enable = true;
  services.forgejo.pushMirrors = [{
    owner = "ccycle";
    repo = "dotfiles";
    remoteUrl = "https://github.com/ccycle/dotfiles.git";
  }];
  custom.lm-studio.enable = true;
  services.llm-server.enable = true;

  services.atticd.enable = true;
  services.staticReports.enable = true;

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
