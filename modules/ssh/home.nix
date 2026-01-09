{ config, pkgs, lib, ... }:

{
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    # Use system SSH on macOS to enable Keychain integration
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extraConfig = lib.mkIf pkgs.stdenv.isDarwin ''
      UseKeychain yes
    '';
  };

  programs.zsh.initContent =
    if pkgs.stdenv.isDarwin then ''
      # SSH Signing: keys in keychain to agent
      # macOS: --apple-load-keychain automatically loads keys from keychain with passphrases.
      # This avoids manual ssh-add and leverages macOS native keychain integration.
      ssh-add --apple-load-keychain > /dev/null 2>&1
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
