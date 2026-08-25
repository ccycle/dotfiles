{ pkgs, pkgs-2211, ... }:

{
  home.packages =
    with pkgs;
    [
      dhall
      dhall-json
      dhall-lsp-server
      erlang
      go
      lean4
      ocaml
      purescript
      scala_3
    ]
    ++ (with pkgs-2211; [
      spago
    ]);
}
