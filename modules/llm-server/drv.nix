{ pkgs, lib }:

# Upstream's prebuilt darwin release, not nixpkgs's ollama: nixpkgs builds
# with -DOLLAMA_MLX_BACKENDS="" (the closed-source `metal` shader compiler
# can't run in the sandbox — same reason modules/llm-server once had to
# substitute Apple's prebuilt mlx wheels), so it has no MLX runner and falls
# back to the llama.cpp engine on Apple Silicon.
pkgs.stdenvNoCC.mkDerivation rec {
  pname = "ollama";
  version = "0.40.16";
  src = pkgs.fetchurl {
    url = "https://github.com/ollama/ollama/releases/download/v${version}/ollama-darwin.tgz";
    sha256 = "a743717494315da7cd352982b805f6b992d4b4452ca117fd5fbf86c4ee46fca0";
  };
  # The tarball has no top-level directory, so it is extracted straight into
  # place. The binary locates its runners (llama-server, mlx_metal_v*/) next
  # to its own resolved path, so the layout is kept intact under libexec and
  # only the entry point is linked into bin.
  dontUnpack = true;
  installPhase = ''
    mkdir -p $out/libexec/ollama $out/bin
    tar xzf $src -C $out/libexec/ollama
    ln -s $out/libexec/ollama/ollama $out/bin/ollama
  '';
  # Mach-O binaries are upstream-signed; any fixup rewrite would break the
  # code signature.
  dontFixup = true;
  meta.platforms = lib.platforms.darwin;
}
