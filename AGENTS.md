# Development Guidelines for Coding Agents

This document outlines the development policies and conventions for the `dotfiles-work` repository. Coding agents must adhere to these rules when implementing changes or adding new features.

## Communication Guidelines

- **Clarify Ambiguities:** If there is ambiguity in the user's instructions regarding the policy, always ask for clarification on the points of contention before starting actual work.

Detailed guidelines are available in the `docs/agents/` directory:

- [Module Structure and Organization](./docs/agents/module-structure.md)
  - **Dependency Clarity:** File dependencies should be evident from the directory structure.
  - Directory structure rules (Package by Feature)
  - Platform separation (nix-darwin vs home-manager)
  - No Cross-Hierarchy Imports
- [Code Reuse Guidelines](./docs/agents/code-reuse.md)
  - Reusing logic from the base `dotfiles` repository
- [Bootstrap Configuration](./docs/agents/bootstrap.md)
  - Purpose and maintenance of the bootstrap profile
- [Credentials Management](./docs/agents/credentials.md)
  - Strategy for managing Nix access tokens and secrets

## Summary Checklist

When asked to implement a feature:

1. **Check Structure:** Does it fit into an existing feature directory? If not, create `modules/<feature>`. Ensure file dependencies are clear from the structure.
2. **Separate Platforms:** Use `darwin/` for system config and `home-manager/` for user config.
3. **Reuse:** Check `dotfiles` repo for existing modules to import.
4. **Credentials:** If adding secrets, follow the credentials strategy (separate files, inclusions).
