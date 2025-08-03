# dotfiles/modules/common/haskell/flake.nix
{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit self; } {
      systems = [ "x86_64-darwin" ];

      perSystem = { system, ... }: {
        # このディレクトリ内のすべての.nixファイルをモジュールとして提供
        _module.args.haskellModules = [
          ./cabal.nix
          ./compiler.nix
          ./haskell-language-server.nix
          ./dev-tools.nix
          ./stack.nix
          ./stack2cabal.nix
          ./ghc-wasm-meta.nix
        ];
      };
    };
}
