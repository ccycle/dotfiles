# Code Reuse Guidelines

## Reuse `dotfiles` Repository

The `dotfiles-work` repository is an extension of the main `dotfiles` repository (usually provided as a flake input).

**Rule:**
- **Reuse first:** Before creating a new module, check if a similar module exists in `dotfiles` and import or configure it.
- **Minimize duplication:** Do not copy-paste code from `dotfiles`. Use imports or overlays.
- `dotfiles-work` should assume the existence of `dotfiles` logic and focus on work-specific overrides, secrets, or additional tools.
