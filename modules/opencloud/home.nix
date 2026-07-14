{ ... }:

{
  programs.zsh.shellAliases = {
    oc-logs = "sudo tail -f /var/log/opencloud.log";
    oc-docker = "docker compose -p opencloud logs -f --tail=100";
    oc-status = "docker compose -p opencloud ps";
  };
}
