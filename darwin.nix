{ config, pkgs, inputs, username, homeDirectory, ... }:

{
  imports = [
    ./bootstrap/modules/darwin.nix
    ./modules/darwin.nix
    inputs.storage-config.darwinModules.default
  ];

  # Required for launchd.user.agents
  system.primaryUser = username;

  users.users."${username}" = {
    home = homeDirectory;
    shell = pkgs.zsh;
  };

  # Home Manager configuration
  home-manager.extraSpecialArgs = inputs.self.extraSpecialArgs.${pkgs.stdenv.hostPlatform.system};
  home-manager.users."${username}" = {
    imports = [
      ./home.nix
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}
