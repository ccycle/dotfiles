{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.obsidianTodoAgent;
  log = "/Users/${config.system.primaryUser}/Library/Logs/obsidian-todo-agent.log";
in
{
  options.services.obsidianTodoAgent = {
    enable = mkEnableOption "daily headless dispatch of Kanban (dotfiles) Todo cards to AgentDrafts/ and plan-only herdr worktrees";

    repoDir = mkOption {
      type = types.str;
      description = "Dotfiles checkout the job runs git/herdr against (worktrees are created from it).";
    };

    model = mkOption {
      type = types.str;
      description = "Ollama model id used for slugs, drafts, and the pi worker.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.llm-server.enable;
        message = "services.obsidianTodoAgent requires services.llm-server.enable = true — vault content must only go to the local LLM.";
      }
    ];

    # User agent: it needs this user's herdr socket, GUI session (to start
    # Obsidian for LiveSync), and pi/opencode config.
    launchd.user.agents.obsidian-todo-agent = {
      serviceConfig = {
        StartCalendarInterval = [
          {
            Hour = 6;
            Minute = 0;
          }
        ];
        StandardOutPath = log;
        StandardErrorPath = log;
      };
      script = ''
        export PATH="/etc/profiles/per-user/${config.system.primaryUser}/bin:${pkgs.jq}/bin:${pkgs.curl}/bin:${pkgs.gawk}/bin:${pkgs.git}/bin:$PATH"
        export REPO_DIR=${escapeShellArg cfg.repoDir}
        export LLM_URL="http://127.0.0.1:${toString config.services.llm-server.port}"
        export MODEL=${escapeShellArg cfg.model}
        exec ${pkgs.bash}/bin/bash ${./scan.sh}
      '';
    };
  };
}
