{ inputs, pkgs, pkgs-unstable, ... }:

{
  programs.ghostty = {
    enable = true;
    package =
      if pkgs.stdenv.isLinux then
        pkgs.ghostty
      else if pkgs.stdenv.isDarwin then
        pkgs.brewCasks.ghostty
      else
        throw "unsupported system ${pkgs.stdenv.hostPlatform.system}";
    settings = {
      theme = "Dark Modern";
    };
  };
}
