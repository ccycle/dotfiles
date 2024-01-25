{ pkgs, ... }: {
  programs.git = {
    userName = "ccycle";
    userEmail = "ccycle713@gmail.com";
    extraConfig = {
      user.signingkey = "1211E56EB24BAC72!";
      commit.gpgsign = true;
    };
  };
}
