{
  rustPlatform,
  pkg-config,
  cmake,
  openssl,
  libiconv,
  lib,
  stdenv,
  src,
}:

rustPlatform.buildRustPackage {
  pname = "gitui";
  version = "from-flake-input";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [
    pkg-config
    cmake
  ];
  buildInputs = [ openssl ] ++ lib.optionals stdenv.isDarwin [ libiconv ];

  postPatch = ''
    rm -f .cargo/config.toml
    rm -f build.rs
    sed -i '/^build\s*=/d' Cargo.toml
  '';

  env = {
    GITUI_BUILD_NAME = "nix";
    OPENSSL_NO_VENDOR = 1;
  };

  doCheck = false;
}
