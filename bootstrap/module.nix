{ inputs, username, homeDirectory, ... }: {
  imports = [
    ./darwin-base.nix
    inputs.sops-nix.darwinModules.sops
    ./modules/sops/darwin.nix
  ];

  home-manager.users.${username} = import ./modules/minimal/home.nix;
  home-manager.extraSpecialArgs = { inherit username homeDirectory; };
  users.users.${username}.home = homeDirectory;
}
