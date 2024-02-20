{ config, pkgs, ... }:

{
  home.packages = with pkgs; [
    # bun
    dhall-lsp-server
    arrow-cpp
    arrow-glib
    cacert
    cachix
    caddy
    cmake
    dhall
    dhall-json
    erlang
    gawk
    gcc
    gcc.cc
    gnugrep
    go
    gnupg
    gpg-tui
    graphviz
    grpcui
    grpcurl
    htop
    ijq
    imagemagick
    inkscape
    jq
    llvm_12
    localstack
    neo4j
    nil
    nix-du
    nix-index
    nix-prefetch-git
    minikube
    # mongodb
    mysql80
    nix-tree
    ocaml
    pkgconfig
    platinum-searcher
    purescript
    rclone
    remarshal
    rename
    ripgrep
    rustup
    scala_3
    shellcheck
    sl
    spago
    sqlite
    sqlitebrowser
    tree
    vagrant
    vault
    xdot
    yq-go
    zlib
    zlib.dev
    zstd
  ];

  programs.home-manager.enable = true;

  imports = [
    ./common/age.nix
    ./common/agenix.nix
    ./common/direnv.nix
    ./common/git.nix
    ./common/go-task.nix
    ./common/php.nix
    ./common/haskell.nix
    ./common/nix-formatter.nix
    ./common/nodejs.nix
    ./common/python.nix
    # ./common/rancher-desktop.nix
    ./common/sops.nix
    ./common/tmux.nix
    ./common/zsh.nix
    ./common/vscode.nix
  ];
}
