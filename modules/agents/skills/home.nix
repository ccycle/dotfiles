{ config, ... }: {
  home.file."${config.home.homeDirectory}/.claude/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/skills";

  # Pi skills directory: symlink to shared user skills
  home.file."${config.home.homeDirectory}/.agents/skills".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/skills";
}
