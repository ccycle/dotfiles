{
  inputs = {
    agenix.url = "github:ryantm/agenix";
    agenix.inputs.home-manager.follows = "home-manager";
    agenix.inputs.nixpkgs.follows = "nixpkgs";
    attic.url = "github:zhaofengli/attic";
    flake-utils.url = "github:numtide/flake-utils";
    ghcup.flake = false;
    ghcup.url = "github:haskell/ghcup-hs";
    ghc-wasm-meta.url = "gitlab:haskell-wasm/ghc-wasm-meta?host=gitlab.haskell.org";
    ghq-migrator.flake = false;
    ghq-migrator.url = "github:astj/ghq-migrator";
    haskellNix.url = "github:input-output-hk/haskell.nix";
    devx.url = "github:input-output-hk/devx";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:nixos/nixpkgs/25.05";
    nixpkgs-2211.url = "github:nixos/nixpkgs/22.11";
    nixpkgs-2305.url = "github:nixos/nixpkgs/23.05";
    nixpkgs-2311.url = "github:nixos/nixpkgs/23.11";
    nixpkgs-2405.url = "github:NixOS/nixpkgs/24.05";
    nixpkgs-2411.url = "github:NixOS/nixpkgs/24.11";
    nixpkgs-2505.url = "github:NixOS/nixpkgs/25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    pip2nix.url = "github:nix-community/pip2nix";
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
    , ghc-wasm-meta
    , haskellNix
    , home-manager
    , nixpkgs
    , nixpkgs-2211
    , nixpkgs-2305
    , nixpkgs-2311
    , nixpkgs-2405
    , nixpkgs-2411
    , nixpkgs-2505
    , nixpkgs-unstable
    , pip2nix
    , sops-nix
    , stack2cabal
    , ...
    }@args: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs-2211 = nixpkgs-2211.legacyPackages.${system};
      pkgs-2305 = nixpkgs-2305.legacyPackages.${system};
      pkgs-2311 = nixpkgs-2311.legacyPackages.${system};
      pkgs-2405 = nixpkgs-2405.legacyPackages.${system};
      pkgs-2411 = nixpkgs-2411.legacyPackages.${system};
      pkgs-2505 = nixpkgs-2505.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
      pkgs = nixpkgs.legacyPackages.${system};
      modules = [ ./modules/common.nix ];
      extraSpecialArgs = args // {
        inherit
          pkgs-unstable
          pkgs-2211
          pkgs-2305
          pkgs-2311
          pkgs-2405
          pkgs-2411
          pkgs-2505
          ;
      };
    in
    {
      inherit pkgs modules extraSpecialArgs;
      packages = {
        init-dotfiles = pkgs.callPackage ./init-dotfiles.nix { };
      };
    });
}
