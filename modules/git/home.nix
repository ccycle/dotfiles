{ pkgs, ... }: {
  programs.git = {
    extraConfig = {
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
