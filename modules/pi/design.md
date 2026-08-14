# pi Design

## Purpose

Install the `pi` coding-agent CLI as a hermetic, Cachix-cacheable Nix package, symlink the shared AI-behavioral rules from `modules/ai-rules` into its config directory — the same live-editable symlink pattern used for Claude and Cursor — and declaratively point pi at the self-hosted local inference server (`modules/llm-server`) via `~/.pi/agent/models.json`.

## Non-Goals

- Building `pi` ourselves via `buildNpmPackage`/`importNpmLock` (the pattern used for `opencode-ai` in `modules/nodejs/node-tools`). Blocked by the npm behavior described below; delegated entirely to the upstream `pi.nix` flake instead.
- Using `pi.nix`'s `programs.pi.coding-agent` home-manager module. Only its `packages.<system>.coding-agent` output is consumed (exposed here as the `piPackage` special arg, alongside `herdrPackage`/`hunkPackage`). The module wraps the binary in a generated shell script that injects `rules`/`settings`/`environment` at runtime instead of writing real files, which doesn't fit this repo's convention of symlinking config files directly into the dotfiles checkout. `jail.enable` (bubblewrap sandboxing) is also part of that module and is Linux-only besides, moot for this Darwin-only repo.
- Declarative management of `~/.pi/agent/settings.json`. That file mixes interactive state pi persists at runtime (the saved `defaultProvider`/`defaultModel` from `/model`, `theme`, etc.); owning it wholesale would clobber those on every rebuild. The saved default also only resolves once models.json actually provides the matching provider/model.

## Why This Structure

`pi`'s dependency tree pulls in a package, nested several levels deep through one of its AI-provider integrations, that npm cannot install strictly from a lockfile: npm re-derives that package's requirements from the *actual* manifest embedded in its dependent's published tarball rather than trusting the lockfile, then falls back to a live registry fetch to reconcile the two. This reproduces with a plain `npm install` or `npm ci --offline`, independent of Nix, and survives editing the lockfile to remove the offending dependency entirely — so no lockfile-level fix is available. It specifically breaks `pkgs.importNpmLock.buildNodeModules` (the mechanism `modules/nodejs/node-tools/drv.nix` uses), because that mechanism reconstructs `node_modules` fully offline inside the build sandbox.

`github:lukasl-dev/pi.nix` avoids this by using plain `buildNpmPackage` with a precomputed `npmDepsHash` instead: the dependency-fetch step runs as a fixed-output derivation, which is allowed network access and is instead verified after the fact by content hash. That sidesteps the specific offline-reconstruction failure entirely. The flake also carries the source patches upstream `pi` needs to build outside its own monorepo tooling (workspace build-order fixes, vendored `models.generated.ts`/provider files, changelog URL rewrites) and stays current: `VERSION.json` is bumped by an automated daily cron job in that repo, tracking upstream releases within about a day (confirmed: pinned to `v0.84.1` here, matching npm's `latest` dist-tag at the time of writing).

The `~/.pi/agent/AGENTS.md` symlink (in `modules/ai-rules/home.nix`) relies on a real `pi` feature, not something `pi.nix` adds: `pi` reads that path as its global instruction file the same way it reads a project-level `AGENTS.md`/`CLAUDE.md`.

## models.json — Pointing pi at the Local Server

`~/.pi/agent/models.json` declares a single custom provider (`llamaswap`, id and URL from `modules/llm-server/catalog.json`, the same single source of truth `modules/opencode/home.nix` consumes) with the catalog's model list. This is the one declarative pi config file that is safe to own: unlike `settings.json` it holds no interactive state.

The provider is a custom `openai-completions` entry rather than pi's built-in `llama.cpp` provider. The built-in one targets a real llama.cpp *router* server (`--models-dir`, `/llama` load/unload, `--no-models-autoload`); llama-swap is not a router — it hot-swaps `llama-server` processes per request and has no router control endpoints. An explicit OpenAI-compatible provider with a fixed model list is the deterministic path, and mirrors how opencode already calls the same server.

`compat` mirrors the flags pi's built-in llama.cpp provider sets (`src/extensions/llama/provider.ts`): `supportsStore`/`supportsDeveloperRole`/`supportsReasoningEffort`/`supportsStrictMode` false, `supportsUsageInStreaming` true, `maxTokensField: "max_tokens"`. llama-swap forwards the request body unchanged to the spawned `llama-server`, so the same server constraints apply. `apiKey: "none"` is a dummy: llama-swap does not authenticate, but pi treats models as available only when the provider has an API key configured.

Models flagged `"thinking": true` in the catalog get `reasoning: true` plus `compat.thinkingFormat: "qwen-chat-template"` with `chatTemplateKwargs` (`enable_thinking` bound to pi's thinking level via `$var`/`thinking.enabled`, `preserve_thinking: true`) — the pi-documented way to drive thinking on a local Qwen chat template. Without the flag (Gemma models), no reasoning is enabled and the request is a plain system-role chat call.

Verified end-to-end against the live server (via `PI_CODING_AGENT_DIR` against a scratch dir): `pi --list-models` shows all catalog models with thinking correctly flagged, and `pi -p` print-mode requests reach llama-swap and return Qwen 3.6 output with `--thinking high`.

## Rejected Alternatives

- **`buildNpmPackage`/`importNpmLock` via `modules/nodejs/node-tools`**: blocked by the npm behavior described above.
- **`pnpm add --global` from a `home.activation` step** (mirroring `modules/herdr`'s imperative-installer pattern): worked and was implemented first, but was abandoned once `pi.nix` was found. It traded away Nix's hermeticity and Cachix caching, required network access on every `darwin-rebuild switch`, and needed an explicit `--ignore-scripts` decision to avoid running arbitrary install scripts with full user permissions outside any sandbox.
- **`node2nix`**: forbidden repository-wide — removed from nixpkgs and unmaintained.
- **`programs.pi.coding-agent.rules`**: works (verified: builds and injects the intended content via `--append-system-prompt`), but was rejected in favor of the plain `home.packages` + symlink approach above, to keep `pi` consistent with how every other agent's rules file is managed in this repo.
- **Built-in `llama.cpp` provider** (via `LLAMA_BASE_URL`/`/login llama.cpp`): targets a llama.cpp router server whose `/llama` model-loading control flow llama-swap cannot serve; see above.

## Constraints

- `pi.nix` pins its own `nixpkgs` (`nixos-unstable`) rather than following this repo's `nixpkgs` input, since its build carries upstream-specific patches tested against that pin. Left un-followed deliberately — forcing `.follows` risks breaking a build that was never tested against this repo's `nixpkgs-26.05`.
- Freshness tracks `pi.nix`'s own sync cadence (daily cron in that repo) plus whenever this repo runs `nix flake update` on the `pi` input — not continuous per-build "latest" like an imperative installer would give.
- `~/.pi/agent/AGENTS.md` only gets `rules.md`, not the topic-specific `rules/nix.md`/`rules/loop-engineering.md` — a real file can only symlink to one source, and `pi` has no directory-of-files convention like Claude's `~/.claude/rules/` to point at instead. This matches how Cursor is already handled in the same file.
- models.json's `baseUrl` is the tailnet hostname `http://llm.mac-mini-m4-pro.internal/v1`, so pi only talks to the local server when the tailnet DNS is reachable and `services.llm-server` is up (mac-mini-m4-pro). The file is generated on every host regardless of that enablement, same as the opencode config.
- The saved default in `settings.json` is not touched by this module; until the default provider is switched to `llamaswap` via `/model`, pi falls back to the first available authenticated model, which may be a cloud provider.
