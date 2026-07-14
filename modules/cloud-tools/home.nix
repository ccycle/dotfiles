{ pkgs, pkgs-2211, ... }:

{
  home.packages = with pkgs; [
    google-cloud-sdk
    grpcui
    grpcurl
    hcp
    k6
    localstack
    minikube
  ] ++ (with pkgs-2211; [
    vault
  ]);
}
