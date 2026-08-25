{ lib, ... }:
{
  options.custom.dotfiles.dir = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Absolute path to the dotfiles repository checkout directory.";
  };
}
