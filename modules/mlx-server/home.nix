{ ... }:

{
  programs.zsh.shellAliases = {
    "mlx-server-start" = "launchctl kickstart -k gui/$(id -u)/org.nixos.mlx-server";
    "mlx-server-stop" = "launchctl kill SIGTERM gui/$(id -u)/org.nixos.mlx-server";
  };
}
