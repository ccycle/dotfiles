{ pkgs, config, ... }: {
  home.packages = [ pkgs.docker ];
  imports = [ ./colima/home.nix ];

  programs.zsh.envExtra = ''
    export DOCKER_HOST="unix://${config.home.homeDirectory}/.colima/default/docker.sock"
  '';
}
