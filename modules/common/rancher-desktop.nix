{ ... }:
{
  programs.zsh.initExtra = ''
    export PATH=$PATH:$HOME/.rd/bin
  '';
}
