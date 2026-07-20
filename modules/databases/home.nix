{ pkgs, pkgs-2505, ... }:

{
  home.packages = with pkgs; [
    arrow-cpp
    arrow-glib
    # mongodb # requires pkgs-2505
    mysql84
    neo4j
    sqlite
    sqlitebrowser
  ];
}
