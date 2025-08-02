{ pkgs, pkgs-2311, ... }:
let
  my-python-packages = ps: with ps; [
    arrow
    cheroot
    docutils
    google-api-python-client
    google-cloud-vision
    mlflow
    pandas
    protobuf
    scikit-learn
    wsgidav
  ];
in
{
  home.packages = [
    (pkgs-2311.python311.withPackages my-python-packages)
  ];
  imports = [
    ./python/pip2nix.nix
    # ./python/serena.nix
    ./python/uv.nix
  ];
}
