{ config, pkgs, lib, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".addKeysToAgent = "yes";
    # Use system SSH on macOS to enable Keychain integration
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
      UseKeychain yes
    '';
  };

  # home.file.".ssh/authorized_keys".text = ''
  #   # ipad-pro-7th-gen
  #   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0Z244BL6t4u5ILComih2Bf1yrL+KXYOCDGwOPc1Ezb 
  # '';

  programs.zsh.initContent =
    if pkgs.stdenv.isDarwin then ''
      # SSH Signing: keys in keychain to agent
      # macOS: --apple-load-keychain automatically loads keys from keychain with passphrases.
      # This avoids manual ssh-add and leverages macOS native keychain integration.
      ssh-add --apple-load-keychain > /dev/null 2>&1

      # Add all private keys in ~/.ssh to the agent
      for key in ~/.ssh/*; do
        if [ -f "$key" ] && grep -q "PRIVATE KEY" "$key"; then
          ssh-add --apple-use-keychain "$key" > /dev/null 2>&1
        fi
      done
    '' else ''
      # SSH Signing: load key to agent
      # Linux: Requires manual agent startup and key addition since no native keychain integration exists.
      # Checks for existing agent (SSH_AUTH_SOCK) to avoid spawning duplicate agents per shell.
      if [ -z "$SSH_AUTH_SOCK" ]; then
         eval "$(ssh-agent -s)" > /dev/null
      fi
      ssh-add ~/.ssh/id_ed25519_signing > /dev/null 2>&1
    '';
}
