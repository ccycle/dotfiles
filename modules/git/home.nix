{ pkgs, ... }: {
  programs.git = {
    settings = {
      alias.fetch-branch = "!f() { git fetch origin \"$1:$1\"; }; f";
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
