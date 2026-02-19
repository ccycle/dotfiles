{ inputs, ... }: # arguments
{ config
, self
, ...
}:
{
  programs.zsh.shellAliases = {
    serena-mcp-server-run = "uv run serena-mcp-server --directory ${inputs.serena}";
  };
}
