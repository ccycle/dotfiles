{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.sessionVariables = {
    BUN_INSTALL = "$HOME/.bun";
  };

  home.sessionPath = [
    "$HOME/.bun/bin"
  ];
}
