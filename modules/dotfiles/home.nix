{ config, lib, dotfilesDir, ... }:
with lib;

let
  cfg = config.custom.dotfiles;
in {
  options.custom.dotfiles.dir = mkOption {
    type = types.str;
    description = ''
      Absolute path to the dotfiles repository checkout directory.
      Set automatically by darwin-rebuild.sh via the DOTFILES_DIR environment variable.
      When undefined (DOTFILES_DIR unset), evaluation fails with a clear error.
    '';
  };

  config = mkIf (dotfilesDir != "") {
    custom.dotfiles.dir = dotfilesDir;
  };
}
