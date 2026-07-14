{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cacert
    gawk
    gnugrep
    htop
    ijq
    jq
    nmap
    p7zip
    platinum-searcher
    poppler-utils
    rbw
    remarshal
    rename
    ripgrep
    shellcheck
    sl
    tree
    unar
    wget
    yq-go
    zstd
  ];
}
