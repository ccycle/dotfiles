{
  config,
  lib,
  dotfilesDir,
  ...
}:
with lib;

let
  cfg = config.custom.dotfiles;
in
{
  options.custom.dotfiles.dir = mkOption {
    type = types.str;
    description = ''
      Absolute path to the dotfiles repository checkout directory.
      Set automatically by darwin-rebuild.sh via .local/dotfiles/flake.nix.
    '';
  };

  config = mkIf (dotfilesDir != "") {
    custom.dotfiles.dir = dotfilesDir;
  };
}
