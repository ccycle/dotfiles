{ config, lib, ... }:

{
  home.file."${config.home.homeDirectory}/.config/opencode/agents/opencode-web.md".source =
    ./agents/opencode-web.md;
}
