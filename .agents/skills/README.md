# Skills

Agent Skills used by this repository, split across two locations by scope. A skill must live in **exactly one** of the two — never both.

## `.agents/skills/` (this directory)

Repo-scoped skills for agents working inside this dotfiles repository. They exercise the flake, the Nix module tree, or repo-specific tooling (`verify-change`, `nix-module`, smoke tests, secret management), so they are useless outside this repository.

Exposed to repo agents via the committed symlink `.claude/skills -> ../.agents/skills`.

## `modules/agents/skills/`

Repo-agnostic skills useful on any machine or repository: git workflows, herdr/obsidian tooling, research and reasoning loops, coaching. None of them reference this repository's internals.

Deployed to `~/.claude/skills` and `~/.agents/skills` by `modules/agents/skills/home.nix`.

## Placement criteria

Put a new skill in `.agents/skills/` if it depends on the repository's structure, scripts, or commands. Otherwise put it in `modules/agents/skills/`.

When in doubt, the deciding question is: would this skill still make sense with the dotfiles repository not checked out? If yes, it belongs in `modules/agents/skills/`.

Every skill directory must contain a `SKILL.md` with `name` and `description` front matter. A skill name must never exist in both trees — that is how the stale `smart-commit` duplicate was introduced.
