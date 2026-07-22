# Nix makes .zshrc read-only, so zplug cannot write to it.
# Use programs.zsh.plugins instead.
# https://discourse.nixos.org/t/zsh-zplug-powerlevel10k-zshrc-is-readonly/30333/3

{ pkgs, ... }:
{
  programs.zsh.plugins = [
    {
      name = "powerlevel10k";
      src = pkgs.zsh-powerlevel10k;
      file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
    }
    {
      name = "powerlevel10k-config";
      src = ./p10k-config;
      file = ".p10k.zsh";
    }
  ];
}
