{ pkgs, ... }: {
  programs.git = {
    enable = true;
    ignores = [
      "*~"
      "*.swp"
      ".DS_Store"
      "worktree-*"
      "*.log"
      "*.local"
      "result-*"
      "result"
      ".my-local-workspace/"
    ];
    extraConfig = {
      commit.gpgsign = true;
      core.ignorecase = false;
      core.editor = "code --wait";
      init.defaultbranch = "main";
      fetch.prune = true;
    };
    aliases = {
      rh = "reset HEAD^";
      ca = "commit --amend";
      list-merged-branch = ''
        !git branch --merged | egrep -v "(^\*|master|main|dev)"
      '';
      delete-merged-branch = ''
        !git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d
      '';
      list-aliases = ''
        !git config --get-regexp ^alias
      '';
      # https://zenn.dev/mary_pp/articles/eaac544eaf600a
      pushf = ''
        !git push --force-with-lease --force-if-includes
      '';
    };
  };
  imports = [
    ./git/ghq.nix
    ./git/github.nix
    ./git/gitlab.nix
  ];
  home.packages = [
    pkgs.git-lfs
    pkgs.git-credential-manager
  ];
}
