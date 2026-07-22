{ config, pkgs, inputs, ... }:

{
  home.packages = [ pkgs.fzf ];

  programs.yazi = {
    enable = true;
    shellWrapperName = "y";
    enableZshIntegration = true;

    plugins = {
      fzf = "${inputs.yazi-plugins}/fzf.yazi";
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
