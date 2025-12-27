{ pkgs, ... }: {
  home.packages = with pkgs; [
    glab
    gitlab-runner
  ];
}
