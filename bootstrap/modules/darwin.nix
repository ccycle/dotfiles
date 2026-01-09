{ username, homeDirectory, ... }:
{
  imports = [
    ./system/darwin.nix
    ./home-manager/darwin.nix
    ./cachix/darwin.nix
    ./git/darwin.nix
    ./nix/darwin.nix
    ./sops/darwin.nix
  ];

  home-manager.users.${username} = import ./home.nix;
  home-manager.extraSpecialArgs = { inherit username homeDirectory; };
  users.users.${username}.home = homeDirectory;
}
