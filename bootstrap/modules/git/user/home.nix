{ ... }:
{
  programs.git = {
    signing = {
      # Path (not literal key content) so security-key-style (sk-ssh-*) formats work too:
      # https://dev.to/li/correctly-telling-git-about-your-ssh-key-for-signing-commits-4c2c
      key = "${./id_ed25519_signing.pub}";
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

  home.file.".ssh/id_ed25519_signing.pub".source = ./id_ed25519_signing.pub;
}
