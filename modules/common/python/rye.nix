{ ... }:
{
  programs.zsh.initExtra = ''
    [ -f "$HOME/.rye/env" ] && source "$HOME/.rye/env"
  ''
  ;
}
