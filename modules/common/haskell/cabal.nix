{ pkgs, ... }:
{
  programs.zsh.shellAliases = {
    curl-stackage-config = "() {curl https://www.stackage.org/$1/cabal.config > cabal.project.freeze}";
  };
  home.sessionVariables = {
    # https://github.com/haskell/cabal/issues/6716#issuecomment-615913601
    LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [ zlib ]);
    C_INCLUDE_PATH = pkgs.lib.makeSearchPath "include" (with pkgs; [ zlib.dev ]);
  };
  home.packages = with pkgs; [
    cabal-install
    haskellPackages.cabal-plan
  ];
  programs.git.ignores = [
    "dist-newstyle"
    ".cabal"
  ];
}
