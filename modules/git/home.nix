{ pkgs, ... }: {
  programs.git = {
    settings = {
      alias.fetch-branch = "!f() { git fetch origin \"$1:$1\"; }; f";
      rebase.updateRefs = true;
      core.ignorecase = false;
      credential.helper = [
        "osxkeychain"
        "oauth -device"
      ];
    };
  };

  home.packages = [
    pkgs.git-credential-oauth
  ];

  imports = [
    ./ghq/home.nix
    ./github/home.nix
    ./gitlab/home.nix
    ./gwq/home.nix
  ];
}
