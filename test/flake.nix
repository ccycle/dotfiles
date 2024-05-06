{
  description = "Home Manager configuration of dotfiles-test";

  inputs = {
    call-flake.url = "github:divnix/call-flake";
    nix-installer.url = "github:DeterminateSystems/nix-installer";
    nix-installer.flake = false;
    home-manager.url = "github:nix-community/home-manager/release-23.11";
  };

  outputs = { self, call-flake, nix-installer, home-manager, ... }:
    let
      dotfiles = call-flake ../.;
      flake-utils = dotfiles.inputs.flake-utils;
    in
    flake-utils.lib.eachDefaultSystem (system:
    let
      extraSpecialArgs = dotfiles.extraSpecialArgs.${system} // {inherit system;};
      pkgs = dotfiles.pkgs.${system};
      modules-common = dotfiles.modules.${system};
    in
    {
      homeConfigurations."dotfiles-test" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ] ++ modules-common;

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        inherit extraSpecialArgs;
      };
      packages.docker = let
        pkgs = dotfiles.inputs.nixpkgs-stable.legacyPackages.${system};
        pkgsLinux = dotfiles.inputs.nixpkgs-stable.legacyPackages.x86_64-linux;
      in import ./docker.nix {inherit pkgs pkgsLinux;};
    }
    );
}
