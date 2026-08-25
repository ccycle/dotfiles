{ config, ... }:
{
  home.file."${config.home.homeDirectory}/.claude/CLAUDE.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/rules/rules.md";

  home.file."${config.home.homeDirectory}/.claude/rules/loop-engineering.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/rules/loop-engineering.md";

  home.file."${config.home.homeDirectory}/.cursor/rules/global-behavioral-rules.mdc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/rules/rules.md";

  # pi reads a single ~/.pi/agent/AGENTS.md and has no directory-of-files
  # convention like Claude's ~/.claude/rules/, so it gets the same treatment
  # as Cursor above: rules.md only, not the topic-specific rules/*.md files.
  home.file."${config.home.homeDirectory}/.pi/agent/AGENTS.md".source =
    config.lib.file.mkOutOfStoreSymlink "${config.custom.dotfiles.dir}/modules/agents/rules/rules.md";
}
