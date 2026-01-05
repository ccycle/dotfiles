{ pkgs, ... }:
let go-task = pkgs.go-task; in
{
  home.packages = [ go-task ];
  programs.git.ignores = [ ".task/" ];
  programs.zsh.plugins = [
    {
      # https://taskfile.dev/installation/#setup-completions
      name = "go-task";
      src = go-task;
      file = "completion/zsh/_task";
    }
  ];
}
