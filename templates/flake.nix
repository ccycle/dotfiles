{
  description = "Home Manager configuration of ${userName}";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    dotfiles.url = "github:ccycle/dotfiles";
    home-manager = {
      url = "github:nix-community/home-manager/release-23.05";
    };
  };

  outputs = { dotfiles, home-manager, ... }:
    let
      system = "x86_64-darwin";
      pkgs = dotfiles.pkgs.${system};
      modules = dotfiles.modules.${system};
      extraSpecialArgs = dotfiles.extraSpecialArgs.${system} // { inherit system; };
    in
    {
      homeConfigurations."${userName}" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./home.nix ] ++ modules;

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
        inherit extraSpecialArgs;
      };
    };
}
