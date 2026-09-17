{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".AddKeysToAgent = "yes";
    # Use system SSH on macOS to enable Keychain integration
    package = lib.mkIf pkgs.stdenv.isDarwin null;
    extraConfig = ''
      SendEnv LANG LC_*
    ''
    + (
      if pkgs.stdenv.isDarwin then
        ''
          UseKeychain yes
        ''
      else
        ""
    );
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
    if pkgs.stdenv.isDarwin then
      ''
        # Signatures use Apple's launchd-managed ssh-agent (no custom socket,
        # so every context shares one agent). The key passphrase lives in the
        # login keychain (one-time `ssh-add --apple-use-keychain` by the user).
        # GUI shells inherit SSH_AUTH_SOCK from launchd; fresh SSH sessions do
        # not, so discover Apple's socket here (its path is per-login). Alive
        # sockets (e.g. a pre-migration custom agent) are left untouched.
        ssh-add -l >/dev/null 2>&1
        _SSH_ADD_STATUS=$?
        if [ $_SSH_ADD_STATUS -ne 0 ]; then
          if [ $_SSH_ADD_STATUS -eq 2 ]; then
            _APPLE_SOCK="$(launchctl print "gui/$UID/com.openssh.ssh-agent" 2>/dev/null | grep -m1 'SSH_AUTH_SOCK =>' | awk '{print $NF}')"
            [ -S "$_APPLE_SOCK" ] && export SSH_AUTH_SOCK="$_APPLE_SOCK"
            unset _APPLE_SOCK
          fi
          ssh-add --apple-load-keychain > /dev/null 2>&1
        fi
        unset _SSH_ADD_STATUS
      ''
    else
      ''
        ${agentSetup}
        ssh-add ~/.ssh/id_ed25519_signing > /dev/null 2>&1
      '';
}
