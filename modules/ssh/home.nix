{ config, pkgs, lib, ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".AddKeysToAgent = "yes";
    # Use system SSH on macOS to enable Keychain integration
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extraConfig = ''
      SendEnv LANG LC_*
    '' + (if pkgs.stdenv.isDarwin then ''
      UseKeychain yes
    '' else "");
  };

  # home.file.".ssh/authorized_keys".text = ''
  #   # ipad-pro-7th-gen
  #   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAID0Z244BL6t4u5ILComih2Bf1yrL+KXYOCDGwOPc1Ezb 
  # '';

  programs.zsh.initContent =
    let
      agentSetup = ''
        _AGENT_SOCK="$HOME/.ssh/agent.sock"
        if [ -S "$_AGENT_SOCK" ]; then
          # Verify the agent behind the socket is alive (exit 2 = can't connect)
          SSH_AUTH_SOCK="$_AGENT_SOCK" ssh-add -l >/dev/null 2>&1 || [ $? -ne 2 ] || rm -f "$_AGENT_SOCK"
        fi
        if [ ! -S "$_AGENT_SOCK" ]; then
          eval "$(ssh-agent -a "$_AGENT_SOCK" -s)" > /dev/null
        fi
        export SSH_AUTH_SOCK="$_AGENT_SOCK"
        unset _AGENT_SOCK
      '';
    in
    if pkgs.stdenv.isDarwin then ''
      ${agentSetup}
      ssh-add --apple-load-keychain > /dev/null 2>&1
    '' else ''
      ${agentSetup}
      ssh-add ~/.ssh/id_ed25519_signing > /dev/null 2>&1
    '';
}
