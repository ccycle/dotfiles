{ ... }:

{
  programs.zsh.shellAliases = {
    immich-logs = "sudo tail -f /var/log/immich.log";
    immich-docker = "docker compose -p immich logs -f --tail=100";
    immich-status = "docker compose -p immich ps";
  };
}
