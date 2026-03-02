{ config, pkgs, inputs, system, ... }:

{
  nixpkgs.hostPlatform = system;

  # Basic nix-darwin configuration
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.nixPath = pkgs.lib.mkForce [ "nixpkgs=${inputs.nixpkgs}" ];

  system.stateVersion = 5;

  system.defaults.NSGlobalDomain.KeyRepeat = 2; # key repeat rate: fast
  system.defaults.NSGlobalDomain.InitialKeyRepeat = 15; # delay until repeat: short
  system.defaults.NSGlobalDomain.AppleInterfaceStyle = "Dark"; # dark mode
  
  system.defaults.dock.mineffect = "scale";
  
  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true; # use Touch ID for sudo authentication
    reattach = true; # equired for Touch ID to work inside tmux/screen
  };

  # Require full disk access
  system.defaults.universalaccess.reduceTransparency = true;
  system.defaults.universalaccess.reduceMotion = true;

  # Disable auto-correct
  system.defaults.NSGlobalDomain = {
    NSAutomaticCapitalizationEnabled = false;
    NSAutomaticSpellingCorrectionEnabled = false;
    NSAutomaticPeriodSubstitutionEnabled = false;
    NSAutomaticDashSubstitutionEnabled = false;
    NSAutomaticQuoteSubstitutionEnabled = false;
  };

  # https://discourse.nixos.org/t/ssl-ca-cert-error-on-macos/31171/11
  system.activationScripts."ssl-ca-cert-fix".text = ''
    if [ ! -f /etc/nix/ca_cert.pem ]; then
      security export -t certs -f pemseq -k /Library/Keychains/System.keychain -o /tmp/certs-system.pem
      security export -t certs -f pemseq -k /System/Library/Keychains/SystemRootCertificates.keychain -o /tmp/certs-root.pem
      cat /tmp/certs-root.pem /tmp/certs-system.pem > /tmp/ca_cert.pem
      sudo mv /tmp/ca_cert.pem /etc/nix/
    fi
  '';

  # This is the main part
  nix.settings = {
    ssl-cert-file = "/etc/nix/ca_cert.pem";
  };
}
