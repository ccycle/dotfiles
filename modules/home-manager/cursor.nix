{ pkgs, ... }: {
  home.sessionVariables = {
    EDITOR = "cursor --wait";
  };
  # programs.git.extraConfig.core.editor = "cursor --wait";
  # home.packages = with pkgs; [ cursor-cli ]; // nixpkgs-25.11
}
