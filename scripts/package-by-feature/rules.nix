# Declarative rules for the Package by Feature structure validator.
# Consumed by check.nix. Canonical prose spec:
# skills/project/nix-module/references/conventions.md
{
  # Module trees to validate, relative to the repo root.
  roots = [
    "modules"
    "bootstrap/modules"
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
  ];

  # Paths (repo-relative) fully exempt from every check.
  exemptPaths = [
    "modules/nodejs/node-tools" # node2nix output (default.nix, node-env.nix, node-packages.nix)
    "modules/storage/default-config" # standalone flake used as --override-input stub
    "modules/obsidian/default-config" # standalone flake used as --override-input stub
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

  # Host profile modules: imported directly by flake.nix, so their parent
  # aggregator does not import them, and they may only set option values —
  # never import sibling features.
  hostModules = [
    "modules/mac-mini-m4"
    "modules/mac-mini-m4-pro"
  ];
}
