# Declarative rules for the Package by Feature structure validator.
# Consumed by check.nix. Canonical prose spec:
# .agents/skills/nix-module/references/conventions.md
{
  # Module trees to validate, relative to the repo root.
  roots = [
    "modules"
  ];

  # Aggregation file names. A directory is a feature module iff it
  # contains at least one of these.
  aggregationFiles = [
    "home.nix"
    "darwin.nix"
  ];

  # Non-aggregation .nix files allowed inside the module trees.
  supportFiles = [
    "options.nix"
    "secrets.nix"
    "drv.nix"
    "gemset.nix"
    "age-keys.nix" # age key ledger: hosts / transitionKeys / per-file recipient rules for sops
    "config.nix" # build-time config derivation helper (e.g. caddy config.nix)
  ];

  # Directory names never descended into: untracked runtime output of
  # co-located tests (npm deps, container data that may be unreadable to the
  # user, Playwright reports). Walking them is slow and can abort the eval.
  skipDirNames = [
    "node_modules"
    ".state"
    "test-results"
  ];

  # Paths (repo-relative) fully exempt from every check.
  exemptPaths = [
    "modules/storage/default-config" # standalone flake used as --override-input stub
    "modules/obsidian/default-config" # standalone flake used as --override-input stub
    "modules/dotfiles/default-config" # standalone flake used as --override-input stub
    "modules/user/default-config" # standalone flake used as --override-input stub
  ];

  # Feature directories intentionally not imported by their parent
  # aggregator (e.g. temporarily disabled via a commented-out import).
  allowUnimported = [
    "modules/haskell/ghc-wasm-meta" # commented out in modules/haskell/home.nix
    "modules/python/pip2nix" # commented out in modules/python/home.nix
  ];

  # Repo-root directories that ../ references may escape into
  # (conventions.md §3 allows shared helpers under utils/).
  crossHierarchyAllowed = [
    "utils"
  ];

  # Module-internal paths that other features consume via ../ even though
  # they are not children (conventions.md §3 dependency rule exceptions).
  # The owner keeps the file; listing it here makes the coupling explicit,
  # and test selection treats a change under it as affecting every feature.
  sharedPaths = [
    "modules/llm-server/catalog.json" # model catalog read by opencode and pi
    "modules/mtplx/catalog.json" # model catalog read by opencode
    "modules/nodejs/node-tools" # npm lockfile reused by opencode-web and pi-web
    "modules/pocket-id/tests/lib" # passkey login helper imported by every pocket-id-fronted e2e suite
  ];

  # Host profile modules: imported directly by flake.nix, so their parent
  # aggregator does not import them, and they may only set option values —
  # never import sibling features.
  hostModules = [
    "modules/mac-mini-m4"
    "modules/mac-mini-m4-pro"
  ];
}
