# Restructure: move system (autogen) under each dotfiles root

## Goal
Change the layout from:
- home-manager
  - dotfiles
  - dotfiles-work
  - generated/system files (autogen)

to:
- home-manager
  - dotfiles
    - generated (autogen)
  - dotfiles-work
    - generated (autogen)

and make the repository robust to first-time evaluation (no pre-generated files required).

## Scope
- Move/duplicate autogen env to `dotfiles/generated/env.nix` and `dotfiles-work/generated/env.nix`.
- Update `flake.nix` to import env from `dotfiles/generated/env.nix`, with safe fallbacks.
- Place `scripts/generate-env.sh` under both `dotfiles/` and `dotfiles-work/`; add a top-level wrapper to run both.
- Aggregate base modules in `dotfiles`; make `dotfiles-work` import modules exported by `dotfiles`.
- Update docs and ignore rules.
- Add `dotfiles/generated` to `.gitignore`

## Affected files
- `flake.nix`
- `scripts/generate-env.sh` (top-level wrapper)
- `dotfiles/scripts/generate-env.sh`
- `dotfiles-work/scripts/generate-env.sh`
- `dotfiles-work/home.nix`
- `docs/dependenciy.md`
- `.gitignore` (or equivalent ignore mechanism)

## Step-by-step

### 1) Create directories

```sh
mkdir -p dotfiles/generated dotfiles-work/generated dotfiles/scripts dotfiles-work/scripts scripts
```

### 2) Add per-scope autogen scripts and a top-level wrapper

Create `dotfiles/scripts/generate-env.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$(dirname "$0")/../generated"

cat > "$(dirname "$0")/../generated/env.nix" << 'EOF'
{
  username = "${USER}";
  homeDirectory = "${HOME}";
}
EOF

echo "Generated dotfiles/generated/env.nix"
```

Create `dotfiles-work/scripts/generate-env.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$(dirname "$0")/../generated"

cat > "$(dirname "$0")/../generated/env.nix" << 'EOF'
{
  username = "${USER}";
  homeDirectory = "${HOME}";
}
EOF

echo "Generated dotfiles-work/generated/env.nix"
```

Create a top-level wrapper `scripts/generate-env.sh` that runs both:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Run both generators
"$(dirname "$0")/../dotfiles/scripts/generate-env.sh"
"$(dirname "$0")/../dotfiles-work/scripts/generate-env.sh"
```

### 3) Make `flake.nix` robust and point to the new path

Change the current env import from:

```nix
env = import ./generated/env.nix;
```

to a safe import with fallbacks:

```nix
let
  envFile =
    if builtins.pathExists ./dotfiles/generated/env.nix then ./dotfiles/generated/env.nix
    else null;
  env =
    if envFile != null then import envFile
    else {
      username = let u = builtins.getEnv "USER"; in if u == "" then "unknown" else u;
      homeDirectory = let h = builtins.getEnv "HOME"; in if h == "" then "/tmp" else h;
    };
in
```

Keep using `env.username` and `env.homeDirectory` as before.

Ensure the app entry calls the top-level wrapper script:

```nix
apps.${system}.generate-env = {
  type = "app";
  program = toString (pkgs.writeShellScript "generate-env" ''
    exec ${./scripts/generate-env.sh}
  '');
};
```

### 4) Aggregate base modules in `dotfiles` and import them from `dotfiles-work`

- Adjust top-level `flake.nix` to only include the `dotfiles-work` module, and pass `dotfiles` via `extraSpecialArgs` so `dotfiles-work/home.nix` can import it.

Change:

```nix
modules = dotfiles.modules.${system} ++ [ module-work ];

extraSpecialArgs = dotfiles.extraSpecialArgs.${system}
  // { inherit system; codex = dotfiles-work.inputs.codex; }
  // env;
```

to:

```nix
modules = [ module-work ];

extraSpecialArgs = dotfiles.extraSpecialArgs.${system}
  // { inherit system; codex = dotfiles-work.inputs.codex; dotfiles = dotfiles; };
```

- Update `dotfiles-work/home.nix` to import modules exported by `dotfiles`:

Change from:

```nix
{ codex, system, ... }:
{
  imports = [
    codex.hmModule.${system}
  ];
  config.codex.enable = true;
  config.codex.ignorePackages = [
    "jq"
    "gh"
    "nixpkgs-fmt"
    "nix-du"
  ];
}
```

to:

```nix
{ dotfiles, codex, system, ... }:
{
  imports = dotfiles.modules.${system} ++ [
    codex.hmModule.${system}
  ];
  config.codex.enable = true;
  config.codex.ignorePackages = [
    "jq"
    "gh"
    "nixpkgs-fmt"
    "nix-du"
  ];
}
```

This ensures the base configuration is centralized in `dotfiles`, while `dotfiles-work` layers in work-specific modules.

### 5) Update docs

Update `docs/dependenciy.md` to reflect the new naming and dependency:

```md
# Dependency

- Directory dependencies:
  - dotfiles/generated (autogen) -> dotfiles
  - dotfiles/generated (autogen) -> dotfiles-work
  - dotfiles -> dotfiles-work
```

### 6) Ignore autogen files

Add to `.gitignore`:

```
dotfiles/generated/env.nix
dotfiles-work/generated/env.nix
```

If the old path existed, also ignore:

```
generated/
```

### 7) Remove old `generated/` usage (optional cleanup)

- After rollout, delete the `generated/` directory if it is no longer used.
- Keep the fallback in `flake.nix` temporarily if you have other machines referencing it.

### 8) Validation

Initial bootstrap (first time on a new machine):

```sh
nix run .#generate-env
```

Evaluate and activate:

```sh
nix build .#homeConfigurations."$USER".activationPackage
./result/activate
```

If using `home-manager` directly through flake:

```sh
home-manager switch --flake .#"${USER}"
```

Expected:
- flake evaluation succeeds even before running `generate-env` (fallback to environment variables).
- After running `generate-env`, `env.username` and `env.homeDirectory` resolve from `dotfiles/generated/env.nix`.
- `dotfiles-work` successfully composes `dotfiles` base modules via `imports`.

## Rollback

- Revert top-level `flake.nix` to include `dotfiles.modules.${system}` directly in `modules`.
- Remove `dotfiles` from `extraSpecialArgs` if not needed.
- Restore `dotfiles-work/home.nix` to only import work-specific modules.
- Revert env generation behavior if required.
