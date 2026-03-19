{ config, pkgs, inputs, system, username, ... }:

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
    reattach = false; # disabled: causes sudo to freeze in SSH+tmux sessions (Touch ID prompt appears on physical Mac)
  };

  security.sudo.extraConfig = ''
    ${username} ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/nix *
    ${username} ALL=(ALL) NOPASSWD: /nix/var/nix/profiles/default/bin/nix *
    ${username} ALL=(ALL) NOPASSWD: /bin/launchctl *
  '';

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
  # Always regenerate so the cert stays fresh and is recreated if deleted.
  system.activationScripts."ssl-ca-cert-fix".text = ''
    echo "Regenerating /etc/nix/ca_cert.pem from macOS keychain..."
    security export -t certs -f pemseq \
      -k /System/Library/Keychains/SystemRootCertificates.keychain \
      -o /tmp/nix-certs-root.pem
    security export -t certs -f pemseq \
      -k /Library/Keychains/System.keychain \
      -o /tmp/nix-certs-system.pem 2>/dev/null || cp /dev/null /tmp/nix-certs-system.pem
    cat /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem > /etc/nix/ca_cert.pem
    rm -f /tmp/nix-certs-root.pem /tmp/nix-certs-system.pem
    echo "Done."
  '';

  # This is the main part
  nix.settings = {
    ssl-cert-file = "/etc/nix/ca_cert.pem";
  };
}
