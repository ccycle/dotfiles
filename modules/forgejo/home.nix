{ ... }:

{
  programs.zsh.shellAliases = {
    forgejo-logs = "sudo tail -f /var/log/forgejo.log";
    forgejo-docker = "docker compose -p forgejo logs -f --tail=100";
    forgejo-status = "docker compose -p forgejo ps";
  };
}
