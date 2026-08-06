{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cmake
    gcc
    gcc.cc
    pkg-config
    protobuf
    zlib
    zlib.dev
  ];
}
