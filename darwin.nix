{
  config,
  lib,
  pkgs,
  inputs,
  username,
  homeDirectory,
  ...
}:

{
  imports = [
    ./modules/darwin.nix
    inputs.home-manager.darwinModules.home-manager
  ];

  config = {
    # Required for launchd.user.agents
    system.primaryUser = username;

    users.users."${username}" = {
      home = homeDirectory;
      shell = pkgs.zsh;
    };

    home-manager.useGlobalPkgs = true;
    home-manager.useUserPackages = true;
    home-manager.backupFileExtension = "backup";
    home-manager.extraSpecialArgs = inputs.self.extraSpecialArgs.${pkgs.stdenv.hostPlatform.system} // {
      dotfilesDir = config.custom.dotfiles.dir;
      inherit username homeDirectory;
    };
    home-manager.users."${username}" = {
      imports = [
        ./home.nix
        inputs.sops-nix.homeManagerModules.sops
        inputs.obsidian-vault-config.homeManagerModules.default
      ];
    };
  };
}
