{ pkgs, pkgs-unstable, ... }: {
  home.sessionVariables = {
    EDITOR = "cursor --wait";
  };
  # programs.git.extraConfig.core.editor = "cursor --wait";
  # home.packages = [ pkgs-unstable.cursor-cli ];
}
