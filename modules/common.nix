{ config, pkgs, pkgs-unstable, pkgs-2211, pkgs-2305, ... }:

let
  packages-2211 = with pkgs-2211; [
    mongodb
    spago
    nix-du
    vault
    xdot
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
    openssh
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
  ++ packages-2211;

  programs.home-manager.enable = true;

  imports = [
    # ./common/attic.nix
    # ./common/rancher-desktop.nix
    # ./common/agenix.nix
    ./common/age.nix
    ./common/cursor.nix
    ./common/direnv.nix
    ./common/emacs.nix
    ./common/git.nix
    ./common/gmake.nix
    ./common/go-task.nix
    ./common/haskell.nix
    ./common/nix-formatter.nix
    ./common/nodejs.nix
    ./common/php.nix
    ./common/python.nix
    ./common/sops.nix
    ./common/tmux.nix
    ./common/vscode.nix
    ./common/zsh.nix
  ];
}
