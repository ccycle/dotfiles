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
}
