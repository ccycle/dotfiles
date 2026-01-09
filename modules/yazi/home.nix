{ config, pkgs, ... }:

let
  yazi-plugins = pkgs.fetchFromGitHub {
    owner = "yazi-rs";
    repo = "plugins";
    rev = "68f7d4898c19dcf50beda251f8143992c3e8371f";
    hash = "sha256-6iA/C0dzbLPkEDbdEs8oAnVfG6W+L8/dYyjTuO5euOw=";
  };
in
{
  home.packages = [ pkgs.fzf ];

  programs.yazi = {
    enable = true;
    enableZshIntegration = true;

    plugins = {
      fzf = "${yazi-plugins}/fzf.yazi";
    };

    keymap = {
      manager = {
        prepend_keymap = [
          {
            on = [ "z" ];
            run = "plugin fzf";
            desc = "Jump to a directory via fzf";
          }
        ];
      };
    };
  };
}
