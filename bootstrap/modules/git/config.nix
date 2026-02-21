{ ... }:
{
  programs.git = {
    userName = "ccycle";
    userEmail = "ccycle713@gmail.com";
    signing = {
      key = builtins.readFile ./id_ed25519_signing.pub;
      gpgPath = "";
      signByDefault = true;
    };
    extraConfig = {
      gpg.format = "ssh";
      commit.gpgsign = "true";
      url = {
        "https://ccycle@github.com/ccycle/" = {
          insteadOf = "https://github.com/ccycle/";
        };
        "https://ccycle@github.com/primal-search/" = {
          insteadOf = "https://github.com/primal-search/";
        };
      };
    };
  };
}
