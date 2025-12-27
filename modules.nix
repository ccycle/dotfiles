{ config, pkgs, pkgs-unstable, pkgs-2211, pkgs-2305, pkgs-2505, ... }:

let
  packages-2211 = with pkgs-2211; [
    spago
    nix-du
    vault
    xdot
  ];
  packages-2505 = with pkgs-2505; [
    # mongodb
  ];
in

{
  home.packages = with pkgs; [
    # bun
    # ffmpeg_5
    # rclone
    arrow-cpp
    arrow-glib
    bundix
    cacert
    cachix
    caddy
    cmake
    devcontainer
    dhall
    dhall-json
    dhall-lsp-server
    erlang
    gawk
    gcc
    gcc.cc
    gnugrep
    gnupg
    go
    google-cloud-sdk
    gpg-tui
    graphviz
    grpcui
    grpcurl
    hcp
    htop
    ijq
    imagemagick
    inkscape
    jq
    just
    k6
    llvm_12
    localstack
    neo4j
    nil
    nix-index
    nix-info
    nix-prefetch-git
    minikube
    mysql80
    nix-tree
    nmap
    ocaml
    p7zip
    pkg-config
    platinum-searcher
    poppler_utils
    purescript
    remarshal
    rename
    ripgrep
    rustup
    scala_3
    shellcheck
    sl
    sqlite
    sqlitebrowser
    tree
    unar
    wireshark
    wget
    yq-go
    zlib
    zlib.dev
    zstd
  ]
  ++ packages-2211
  ++ packages-2505;

  programs.home-manager.enable = true;

  imports = [
    ./modules/age.nix
    ./modules/cursor.nix
    ./modules/direnv.nix
    ./modules/docker.nix
    ./modules/emacs.nix
    ./modules/git.nix
    ./modules/gmake.nix
    ./modules/go-task.nix
    ./modules/haskell.nix
    ./modules/nix-formatter.nix
    ./modules/nodejs.nix
    ./modules/php.nix
    ./modules/python.nix
    ./modules/sops.nix
    ./modules/ssh.nix
    ./modules/tmux.nix
    ./modules/zsh.nix
    ./modules/pinentry_mac.nix
  ];
}
