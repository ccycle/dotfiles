{ ... }: {
  programs.git.settings = {
    credential.gitHubAuthModes = "device";
    credential.guiPrompt = false;
  };

  imports = [
    ./gh/home.nix
    ./safe-push/home.nix
  ];
}
