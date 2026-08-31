{
  lib,
  username,
  homeDirectory,
  ...
}:
{
  imports = [
    ./attic/darwin.nix
    ./system/darwin.nix
    ./home-manager/darwin.nix
    ./git/darwin.nix
    ./nix/darwin.nix
    ./sops/darwin.nix
  ];

  # Guarded behind mkIf so the main darwin.nix assertion fires first with
  # a clean "username is not set" message instead of the confusing type error.
  config = lib.mkIf (username != "") {
    # Required for system.defaults.* and other primary-user options (nix-darwin migration).
    system.primaryUser = username;

    home-manager.users.${username} = import ./home.nix;
    home-manager.extraSpecialArgs = { inherit username homeDirectory; };
    users.users.${username}.home = homeDirectory;
  };
}
