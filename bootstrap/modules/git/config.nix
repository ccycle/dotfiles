{ ... }:
{
  programs.git = {
    signing = {
      key = builtins.readFile ./id_ed25519_signing.pub;
      signer = "";
      signByDefault = true;
    };
    settings = {
      user.name = "ccycle";
      user.email = "ccycle713@gmail.com";
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
