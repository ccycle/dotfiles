# Nix-managed macOS dotfiles

Declarative system and home configuration using nix-darwin, home-manager, and flake inputs. See [AGENTS.md](./AGENTS.md) for full development policies.

## Quick Reference

### Slash Commands (Skills)

| Command | Description |
|---|---|
| `/nix-module` | Create a new feature module |
| `/verify-change` | Run syntax checks, lints, and build dry-runs |
| `/credentials-manager` | Manage secrets and Nix access tokens |
| `/darwin-rebuild` | Apply Darwin system configuration |
| `/setup-local-storage` | Create or update machine-local storage config |
| `/investigate-service` | Root-cause a service problem via Prometheus/Loki APIs |
| `/cachix-push` | Build and push to Cachix cache |
| `/smart-commit` | Smart commit with conventional format |
| `/push` | Push current branch to origin |
| `/force-push` | Force push with `--force-with-lease` |
| `/merge-to-main` | Merge current branch into main |
| `/git-rebase` | Rebase current branch |

### Profile Build Attribute Paths

Each profile has a different `nix build` attribute path due to how they are defined in `flake.nix`:

| Profile | Attribute Path |
|---|---|
| bootstrap | `./bootstrap#darwinConfigurations.bootstrap.aarch64-darwin.system` |
| private | `.#darwinConfigurations.private.aarch64-darwin.system` |
| mac-mini-m4 | `.#darwinConfigurations.mac-mini-m4.system` (no architecture suffix) |
| mac-mini-m4-pro | `.#darwinConfigurations.mac-mini-m4-pro.system` (no architecture suffix) |

**Why the difference:** `private` is wrapped with `forDarwinSystems`, so the key includes the architecture name. `mac-mini-m4` and `mac-mini-m4-pro` call `darwinSystem` directly, so there is no architecture suffix. See `flake.nix` for details.

### Settings Files

- `modules/claude/settings.json` (symlinked to `~/.claude/settings.json` via home-manager) — permissions, hooks, model
- `.claude/settings.local.json` (tracked in repo) — repository-specific permission overrides

### Workflow

1. Start complex changes with Plan Mode
2. Use `/nix-module` to scaffold new feature modules
3. Run `/verify-change` before committing
4. Use `/darwin-rebuild` to apply changes after verification
