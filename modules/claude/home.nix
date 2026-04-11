{ pkgs, inputs, config, ... }: {
  home.packages = [
    inputs.nix-claude-code.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file."${config.home.homeDirectory}/.claude/skills".source = config.lib.file.mkOutOfStoreSymlink "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/skills/user";

  home.file."${config.home.homeDirectory}/.claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/claude/settings.json";

  programs.git.ignores = [
    ".claude/worktrees/"
  ];
}
