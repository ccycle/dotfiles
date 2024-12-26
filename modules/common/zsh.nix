{ pkgs, ... }:
{
  home.packages = with pkgs; [
    findutils
    coreutils
  ];
  programs.zsh = {
    enable = true;
    dotDir = ".config/zsh";
    shellAliases = {
      hm-switch = "home-manager switch --flake ";
      zsh-restart = "exec zsh -l";
      nix-daemon-restart = "sudo launchctl kickstart -k system/org.nixos.nix-daemon";
      flake-update-input = "nix flake lock --update-input ";
      grep-colorize-only = "grep --color=auto -z ";
    };
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    completionInit =
      ''
        # https://stackoverflow.com/questions/67136714/how-to-properly-call-compinit-and-bashcompinit-in-zsh
        autoload -Uz compinit bashcompinit && compinit && bashcompinit
      '';
    initExtra =
      ''
        bindkey '^[^?' backward-kill-word
        bindkey '^[[3;3~' backward-kill-word
      '';
  };
  imports = [ ./zsh/powerlevel10k.nix ];
}
