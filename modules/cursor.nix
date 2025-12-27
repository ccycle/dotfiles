{ ... }: {
  home.sessionVariables = {
    EDITOR = "cursor";
  };
  programs.git.ignores = [ ".vscode" ];
}
