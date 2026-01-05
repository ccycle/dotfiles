{ serena, ... }: {
  programs.zsh.shellAliases = {
    serena-mcp-server-run = "(cd ${serena} && uv run serena-mcp-server)";
  };
}
