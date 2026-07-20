{ config, ... }: {
  home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/ai-rules/rules.md";

  home.file."${config.home.homeDirectory}/.claude/rules/nix.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/ai-rules/rules/nix.md";

  home.file."${config.home.homeDirectory}/.claude/rules/loop-engineering.md".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/ai-rules/rules/loop-engineering.md";

  home.file."${config.home.homeDirectory}/.cursor/rules/global-behavioral-rules.mdc".source =
    config.lib.file.mkOutOfStoreSymlink
      "${config.programs.git.settings.ghq.root}/github.com/ccycle/dotfiles/modules/ai-rules/rules.md";
}
