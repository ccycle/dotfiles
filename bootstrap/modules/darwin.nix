{ username, homeDirectory, ... }:
{
  # Required for system.defaults.* and other primary-user options (nix-darwin migration).
  system.primaryUser = username;

  imports = [
    ./attic/darwin.nix
    ./system/darwin.nix
    ./home-manager/darwin.nix
    ./git/darwin.nix
    ./nix/darwin.nix
    ./sops/darwin.nix
  ];

  home-manager.users.${username} = import ./home.nix;
  home-manager.extraSpecialArgs = { inherit username homeDirectory; };
  users.users.${username}.home = homeDirectory;
}
