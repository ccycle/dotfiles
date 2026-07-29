{ ... }:

{
  programs.zsh.shellAliases = {
    pocket-id-logs = "sudo tail -f /var/log/pocket-id.log";
    pocket-id-docker = "docker compose -p pocket-id logs -f --tail=100";
    pocket-id-status = "docker compose -p pocket-id ps";
  };
}
