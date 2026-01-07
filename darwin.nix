{ config, pkgs, inputs, system, username, homeDirectory, ... }:

{
  imports = [
    ./modules/darwin.nix
  ];

  # Required for launchd.user.agents
  system.primaryUser = username;

  users.users."${username}" = {
    home = homeDirectory;
    shell = pkgs.zsh;
  };

  # Home Manager configuration
  home-manager.extraSpecialArgs = inputs.self.extraSpecialArgs.${system};
  home-manager.users."${username}" = {
    imports = [
      ./home.nix
      inputs.sops-nix.homeManagerModules.sops
    ];
  };
}
