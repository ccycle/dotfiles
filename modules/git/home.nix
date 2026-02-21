{ pkgs, ... }: {
  programs.git = {
    settings = {
      rebase.updateRefs = true;
      core.ignorecase = false;
    };
  };

  imports = [
    ./ghq.nix
    ./gwq.nix
    ./github.nix
    ./gitlab.nix
  ];
}
