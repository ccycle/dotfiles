{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cmake
    gcc
    gcc.cc
    pkg-config
    zlib
    zlib.dev
  ];
}
