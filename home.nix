{ config, lib, pkgs, username, homeDirectory, pkgs-unstable, pkgs-2211, pkgs-2305, pkgs-2505, ... }:

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
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  # home.username = username;
  # home.homeDirectory = homeDirectory;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  # home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # bun
    # ffmpeg_5
    # rclone
    age
    arrow-cpp
    arrow-glib
    bat # for fzf preview
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
    fd # for fzf file search
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
    k6
    # llvm_12
    localstack
    minikube
    mysql80
    neo4j
    nil
    nix-index
    nix-info
    nix-prefetch-git
    nix-tree
    nmap
    ocaml
    p7zip
    pkg-config
    platinum-searcher
    # poppler_utils
    purescript
    rbw
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
    wget
    wireshark
    yq-go
    zlib
    zlib.dev
    zstd
  ]
  ++ packages-2211
  ++ packages-2505;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. If you don't want to manage your shell through Home
  # Manager then you have to manually source 'hm-session-vars.sh' located at
  # either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/mfuruki/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Enable XDG Base Directory Specification
  # xdg.enable = true;

  # Let Home Manager install and manage itself.
  # programs.home-manager.enable = true;

  imports = [
    ./bootstrap/modules/home.nix
    ./modules/home.nix
  ];
}
