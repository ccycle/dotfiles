{ pkgs, ... }:
{
  home.packages = with pkgs; [
    findutils
    coreutils
  ];
  programs.zsh = {
    enable = true;
    shellAliases = {
      hm-switch = "home-manager switch -L --impure"; # 環境変数を読み取る処理を入れるため `--impure` をつけている
      zsh-restart = "exec zsh -l";
      nix-daemon-restart = "sudo launchctl kickstart -k system/org.nixos.nix-daemon";
      nix-flake-update-input = "nix flake lock --update-input ";
      grep-colorize-only = "grep --color=auto -z ";
      oc-logs = "sudo tail -f /var/log/opencloud.log";
      oc-docker = "DOCKER_HOST=unix:///Users/mfuruki/.colima/default/docker.sock docker compose -p opencloud logs -f --tail=100";
      oc-status = "DOCKER_HOST=unix:///Users/mfuruki/.colima/default/docker.sock docker compose -p opencloud ps";
    };
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    completionInit =
      ''
        # https://stackoverflow.com/questions/67136714/how-to-properly-call-compinit-and-bashcompinit-in-zsh
        autoload -Uz compinit bashcompinit && compinit && bashcompinit
      '';
    initContent =
      ''
        bindkey '^[^?' backward-kill-word
        bindkey '^[[3;3~' backward-kill-word
      '';
    history = {
      size = 100000;
      save = 100000;
      ignoreDups = true;
      share = true;
      extended = true;
    };
  };
  imports = [ ./powerlevel10k.nix ];
  custom.syncHomeFiles.enable = true;
  custom.syncHomeFiles.files = [
    # ".zshenv"
    # ".zshrc"
  ];
  custom.syncHomeFiles.directories = [
    ".config/zsh"
  ];
}
