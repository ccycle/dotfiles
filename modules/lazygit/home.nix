{ pkgs, ... }:
{
  programs.lazygit = {
    enable = true;
    settings = {
      git.pagers = [
        {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        }
      ];
    };
  };

  home.packages = [ pkgs.delta ];
}
