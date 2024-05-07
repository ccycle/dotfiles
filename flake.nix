{
  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs-stable";
    attic.url = "github:zhaofengli/attic";
    flake-utils.url = "github:numtide/flake-utils";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    devx.url = "github:input-output-hk/devx";
    home-manager.url = "github:nix-community/home-manager/release-23.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs-stable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/ec668b72d2bad1350fb35cb42891eaa50a59c41a";
    nixpkgs-stable.url = "github:nixos/nixpkgs/23.11";
    pip2nix.url = "github:nix-community/pip2nix";
    sops-nix.inputs.nixpkgs-stable.follows = "nixpkgs-stable";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs-stable";
    sops-nix.url = "github:Mic92/sops-nix";
    stack2cabal.inputs.haskellNix.follows = "haskellNix";
    stack2cabal.inputs.nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    stack2cabal.url = "github:hasufell/stack2cabal";
  };

  outputs =
    { self
    , agenix
    , attic
    , devx
    , flake-utils
    , ghq-migrator
    , haskellNix
    , home-manager
    , nixpkgs-stable
    , nixpkgs-unstable
    , pip2nix
    , sops-nix
    , stack2cabal
    , ...
    }@args: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      pkgs-stable = nixpkgs-stable.legacyPackages.${system};
      pkgs = pkgs-stable;
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
