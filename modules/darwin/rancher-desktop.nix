{ ... }:
{
  programs.zsh.initContent = ''
    export PATH=$PATH:$HOME/.rd/bin
  '';
}
