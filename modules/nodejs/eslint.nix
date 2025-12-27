{ pkgs, ... }: {
  home.packages = with pkgs; [ nodePackages_latest.eslint ];
  programs.git.ignores = [ ".eslintcache/" ];
}
