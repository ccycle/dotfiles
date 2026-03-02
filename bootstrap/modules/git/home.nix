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
    settings = {
      core.ignorecase = false;
      init.defaultbranch = "main";
      fetch.prune = true;
      # https://qiita.com/skkzsh/items/11dd107a0734fec682b8
      credential = {
        helper = "manager";
      };
      alias = {
        rh = "reset HEAD^";
        stash-abort = "reset --merge";
        poh = "push origin HEAD";
        push-origin-head = "push origin HEAD";
        poh-f = "push origin HEAD --force-with-lease";
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
        aliases-list = ''
          !git config --get-regexp ^alias;
        '';
        # https://zenn.dev/mary_pp/articles/eaac544eaf600a
        push-force-with-lease = ''
          !git push --force-with-lease --force-if-includes
        '';
      };
    };
  };
  imports = [
    ./config.nix
  ];
  home.packages = [
    pkgs.git-lfs
    pkgs.git-credential-manager
  ];

  home.file.".ssh/id_ed25519_signing.pub".source = ./id_ed25519_signing.pub;
}
