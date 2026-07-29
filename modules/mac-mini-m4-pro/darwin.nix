{ ... }:

{
  networking.hostName = "mac-mini-m4-pro";

  services.tailscale.splitDns.enable = true;
  services.opencloud.enable = true;
  services.caddy.enable = true;
  custom.dnsmasq.enable = true;
  services.immich.enable = true;
  services.monitoring.enable = true;
  services.gitlab.enable = true;
  services.forgejo.enable = true;
  services.forgejo.pushMirrors = [{
    owner = "ccycle";
    repo = "dotfiles";
    remoteUrl = "https://github.com/ccycle/dotfiles.git";
  }];
  custom.lm-studio.enable = true;
  services.llm-server.enable = true;

  services.atticd.enable = true;
  services.attic-watch-store = {
    enable = true;
    cacheName = "dotfiles";
  };

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
