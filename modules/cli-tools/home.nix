{ pkgs, ... }:

let
  rbwWithTerminalEditor = pkgs.symlinkJoin {
    name = "rbw-terminal-editor";
    paths = [ pkgs.rbw ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "rbw";
    postBuild = ''
      wrapProgram $out/bin/rbw --set VISUAL /usr/bin/vi
    '';
  };
in
{
  home.packages = with pkgs; [
    bws
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
    rbwWithTerminalEditor
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
