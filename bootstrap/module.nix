{ inputs, username, homeDirectory, ... }: {
  imports = [
    ./darwin-base.nix
    inputs.sops-nix.darwinModules.sops
    ./modules/darwin/sops.nix
  ];

  home-manager.users.${username} = import ./modules/home-manager/minimal.nix;
  home-manager.extraSpecialArgs = { inherit username homeDirectory; };
  users.users.${username}.home = homeDirectory;
}
