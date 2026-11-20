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
    default = "";
    description = "Absolute path to the dotfiles repository checkout directory.";
  };

  config = mkIf (dotfilesDir != "") {
    custom.dotfiles.dir = dotfilesDir;
  };
}
