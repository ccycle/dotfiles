{ pkgs, ... }: {
  programs.git = {
    userName = "${userName}";
    userEmail = "${userEmail}";
    extraConfig = {
      user.signingkey = "${gpgKey}!";
      commit.gpgsign = true;
    };
  };
}
