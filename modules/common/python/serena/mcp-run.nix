{ serena, ... }: # arguments
{ config
, self
, inputs
, ...
}:
{
  programs.zsh.shellAliases = {
    serena-mcp-server-run = "uv run serena-mcp-server --directory ${serena}";
  };
}
