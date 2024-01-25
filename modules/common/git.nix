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
      list-merged-branch = ''
        !git branch --merged | egrep -v "(^\*|master|main|dev|skip_branch_name)"
      '';
      delete-merged-branch = ''
        !git list-merged-branches | xargs git branch -d
      '';
      list-aliases = ''
        !git config --get-regexp ^alias
      '';
    };
  };
  imports = [
    ./git/ghq.nix
    ./git/github.nix
    ./git/gitlab.nix
  ];
}
