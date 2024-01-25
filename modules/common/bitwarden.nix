{ pkgs, ... }:
{
  programs.rbw = {
    enable = true;
    settings = {
      email = "m.furuki.phys@gmail.com";
      # lock_timeout = 300;
      # pinentry = "gnome3";
    };
  };
}
