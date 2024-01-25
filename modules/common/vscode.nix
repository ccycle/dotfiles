{ ... }: {
  home.sessionVariables = {
    EDITOR = "code";
  };
  programs.git.ignores = [ ".vscode" ];
}
