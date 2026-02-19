{ inputs, ... }: {
  programs.zsh.shellAliases = {
    serena-mcp-server-run = "(cd ${inputs.serena} && uv run serena-mcp-server)";
  };
}
