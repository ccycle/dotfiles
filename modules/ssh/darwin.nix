{ config, pkgs, ... }:

{
  # Enable Remote Login (SSH) via systemsetup
  system.activationScripts.postActivation.text = ''
    # Enable Remote Login (SSH)
    # This corresponds to System Settings -> General -> Sharing -> Remote Login
    echo "Enabling Remote Login..."
    sudo systemsetup -setremotelogin on

    # Disable "Block all incoming connections" in Firewall
    # If this is enabled, it blocks SSH even if Remote Login is on.
    # echo "Disabling Firewall 'Block all incoming connections'..."
    # sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setblockall off
  '';
}
