# Bootstrap Configuration

The `bootstrap/` directory contains a minimal configuration designed to run *before* the main system build.

**Purpose:**
- Provide just enough credentials (e.g., GitHub Personal Access Tokens) to allow Nix to fetch private repositories (like `dotfiles-work` itself or private flake inputs).
- Enable basic Git operations required to clone the repository.

**Necessity:**
- Since `dotfiles-work` and its inputs are private, the initial `nix build` or `darwin-rebuild` will fail without authentication.
- The bootstrap profile generates necessary files (like `/etc/nix/access-tokens.conf`) to unblock the main build.

**Maintenance Guidelines:**
- **Keep it minimal:** Do not add features to `bootstrap/` unless they are strictly required for the initial clone/fetch process.
- **Stability over reuse:** While code reuse is generally good, the bootstrap configuration should remain simple and self-contained to avoid circular dependencies or breakage that prevents system recovery.
- **Focus on credentials:** Its primary job is to provision secrets (via `sops-nix` or similar) and configure Git access.
