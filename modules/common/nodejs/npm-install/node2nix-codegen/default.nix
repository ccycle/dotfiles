{ pkgs }:

pkgs.stdenv.mkDerivation {
  name = "node2nix-codegen";
  version = "0.1.0";

  src = pkgs.lib.sourceByRegex ./. [
    "package\.json"
    "package-lock\.json"
  ];

  nativeBuildInputs = with pkgs; [
    node2nix
  ];

  buildPhase = ''
    echo "Generating node packages from package.json..."
    node2nix
    echo "Node packages generated successfully!"
  '';

  installPhase = ''
    mkdir -p $out
    cp default.nix $out/
    cp node-env.nix $out/
    cp node-packages.nix $out/
  '';

  meta = with pkgs.lib; {
    description = "Generate node-env.nix and node-packages.nix using node2nix";
    platforms = platforms.unix;
  };
}
