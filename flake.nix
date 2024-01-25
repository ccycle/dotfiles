{
  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs-2305";
    agenix.url = "github:ryantm/agenix";
    flake-utils.url = "github:numtide/flake-utils";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    devx.url = "github:input-output-hk/devx";
    home-manager.url = "github:nix-community/home-manager/release-23.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-2305";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/ec668b72d2bad1350fb35cb42891eaa50a59c41a";
    nixpkgs-2305.url = "github:nixos/nixpkgs/release-23.05";
    pip2nix.url = "github:nix-community/pip2nix";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs-2305";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-2305";
    sops-nix.url = "github:Mic92/sops-nix";
    stack2cabal.inputs.haskellNix.follows = "haskellNix";
    stack2cabal.inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    stack2cabal.url = "github:hasufell/stack2cabal";
  };

  outputs =
    { self
    , agenix
    , devx
    , flake-utils
    , ghq-migrator
    , haskellNix
    , home-manager
    , nixpkgs-2305
    , nixpkgs-unstable
    , pip2nix
    , sops-nix
    , stack2cabal
    , ...
    }@args: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      pkgs-2305 = nixpkgs-2305.legacyPackages.${system};
      pkgs = pkgs-2305;
      modules = [ ./modules/common.nix ];
      extraSpecialArgs = args // { inherit pkgs-unstable; };
    in
    {
      inherit pkgs modules extraSpecialArgs;
      packages = {
        init-dotfiles = pkgs.callPackage ./init-dotfiles.nix { };
      };
    });
}
