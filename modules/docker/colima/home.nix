{ pkgs, config, ... }: {
  home.packages = [ pkgs.colima ];

  home.file."${config.home.homeDirectory}/.colima/default/colima.yaml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/docker/colima/colima.yaml";
}
