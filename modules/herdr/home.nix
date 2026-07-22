{ herdrPackage, config, ... }:

{
  home.packages = [ herdrPackage ];

  home.file."${config.home.homeDirectory}/.config/herdr/config.toml".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/herdr/config.toml";
}
