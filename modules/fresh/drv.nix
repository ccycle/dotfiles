{ rustPlatform, pkg-config, lib, stdenv, apple-sdk_15, src }:

rustPlatform.buildRustPackage {
  pname = "fresh";
  version = "from-flake-input";
  inherit src;

  cargoHash = "sha256-6eYu1XCZL/RBlntEu6Cvynp0PudgjIPvVJ8rdKxYRtw=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = lib.optionals stdenv.isDarwin [
    apple-sdk_15
  ];

  cargoBuildFlags = [ "--package" "fresh-editor" ];

  doCheck = false;
}
