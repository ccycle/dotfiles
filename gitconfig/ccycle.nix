{ ... }: {
  programs.git = {
    userName = "ccycle";
    userEmail = "ccycle713@gmail.com";
    signing.key = "FBD2B7A9FA8F84FE!";
    extraConfig = {
      url = {
        "https://ccycle713@github.com/ccycle/" = {
          insteadOf = "https://github.com/ccycle/";
        };
      };
    };
  };
}
