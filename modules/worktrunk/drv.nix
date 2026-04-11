{ rustPlatform, pkg-config, lib, stdenv, apple-sdk_15, libiconv, tree-sitter, src }:

rustPlatform.buildRustPackage {
  pname = "worktrunk";
  version = "from-flake-input";
  inherit src;

  cargoHash = "sha256-+W1Yxr52s+WYOLdLK+q4hoRKJiC1F7dmOQ9hwEgQoFQ=";

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    tree-sitter
  ] ++ lib.optionals stdenv.isDarwin [
    apple-sdk_15
    libiconv
  ];

  cargoBuildFlags = [ "--package" "worktrunk" ];

  # vergen-gitcl needs git info; VERGEN_IDEMPOTENT makes it emit
  # placeholder values when .git isn't available (which is the case in
  # Nix builds since the flake input source does not include .git).
  VERGEN_IDEMPOTENT = "1";

  doCheck = false;
}
