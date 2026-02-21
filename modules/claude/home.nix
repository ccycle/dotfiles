{ pkgs, inputs, config, ... }: {
  home.packages = [
    inputs.claude-code-nix.packages.${pkgs.system}.claude-code
  ];

  home.file."${config.home.homeDirectory}/.claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.programs.git.extraConfig.ghq.root}/github.com/ccycle/dotfiles/skills";

  home.file."${config.home.homeDirectory}/.claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.programs.git.extraConfig.ghq.root}/github.com/ccycle/dotfiles/modules/claude/settings.json";
}
