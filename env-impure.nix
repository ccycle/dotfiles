{
  username =
    if builtins.getEnv "SUDO_USER" != "" then
      builtins.getEnv "SUDO_USER"
    else
      builtins.getEnv "USER";
  homeDirectory =
    if builtins.getEnv "SUDO_USER" != "" then
      if builtins.pathExists "/Users" then
        "/Users/${builtins.getEnv "SUDO_USER"}"
      else
        "/home/${builtins.getEnv "SUDO_USER"}"
    else
      builtins.getEnv "HOME";
  dotfilesDir = builtins.getEnv "DOTFILES_DIR";
}
