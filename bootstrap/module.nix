{ username, homeDirectory, ... }: {
  imports = [
    ./darwin-base.nix
  ];

  home-manager.users.${username} = import ./modules/home.nix;
  home-manager.extraSpecialArgs = { inherit username homeDirectory; };
  users.users.${username}.home = homeDirectory;
}
