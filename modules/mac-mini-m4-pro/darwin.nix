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
  custom.lm-studio.enable = true;

  # Enable macOS Remote Login (SSH on port 22)
  system.activationScripts.postActivation.text = ''
    if ! systemsetup -getremotelogin | grep -q "On"; then
      systemsetup -setremotelogin on
    fi
  '';
}
