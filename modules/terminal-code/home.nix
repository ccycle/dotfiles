{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.sessionPath = [
    "$HOME/.local/bin"
  ];
}
