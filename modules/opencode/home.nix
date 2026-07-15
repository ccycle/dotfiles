{ config, ... }:

{
  home.file."${config.home.homeDirectory}/.config/opencode/opencode.json".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/opencode/opencode.json";
}
