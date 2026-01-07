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
      core.ignorecase = false;
      init.defaultbranch = "main";
      fetch.prune = true;
      # https://qiita.com/skkzsh/items/11dd107a0734fec682b8
      credential = {
        helper = "manager";
      };
    };
    aliases = {
      rh = "reset HEAD^";
      stash-abort = "reset --merge";
      push-origin-head = "push origin HEAD";
      push-origin-head-force-with-lease = "push origin HEAD --force-with-lease";
      pull-origin-head = "pull origin HEAD";
      discard-unstaged-changes = "restore .";
      ca = "commit --amend";
      merged-branch-list = ''
        !git branch --merged | egrep -v "(^\*|master|main|dev)"
      '';
      merged-branch-delete = ''
        !git branch --merged | egrep -v "(^\*|master|main|dev)" | xargs git branch -d
      '';
      aliases-list = "git config --get-regexp ^alias";
      push-force-with-lease = "git push --force-with-lease --force-if-includes"; # https://zenn.dev/mary_pp/articles/eaac544eaf600a
    };
  };
  imports = [
    ./config.nix
  ];
  home.packages = [
    pkgs.git-lfs
    pkgs.git-credential-manager
  ];
}
