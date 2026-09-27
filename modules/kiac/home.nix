{ pkgs, inputs, ... }:
let
  # inputs.kiac-release is a plain darwin/arm64 release tarball (LICENSE,
  # README.md, kiac binary at the top level) — Nix's flake tarball fetcher
  # already extracts it, so this just copies the binary into $out/bin.
  kiac = pkgs.stdenv.mkDerivation {
    pname = "kiac";
    version = "0.7.1";
    src = inputs.kiac-release;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp kiac "$out/bin/kiac"
      chmod +x "$out/bin/kiac"
      runHook postInstall
    '';
  };
in
{
  home.packages = [ kiac ];
}
