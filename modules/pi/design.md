# pi Design

## Purpose

Install the `pi` coding-agent CLI as a hermetic, Cachix-cacheable Nix package, symlink the shared AI-behavioral rules from `modules/ai-rules` into its config directory — the same live-editable symlink pattern used for Claude and Cursor — and declaratively point pi at the self-hosted local inference server (`modules/llm-server`) via `~/.pi/agent/models.json`.

## Non-Goals

- Building `pi` ourselves via `buildNpmPackage`/`importNpmLock` (the pattern used for `opencode-ai` in `modules/nodejs/node-tools`). Blocked by the npm behavior described below; delegated entirely to the upstream `pi.nix` flake instead.
- Using `pi.nix`'s `programs.pi.coding-agent` home-manager module. Only its `packages.<system>.coding-agent` output is consumed (exposed here as the `piPackage` special arg, alongside `herdrPackage`/`hunkPackage`). The module wraps the binary in a generated shell script that injects `rules`/`settings`/`environment` at runtime instead of writing real files, which doesn't fit this repo's convention of symlinking config files directly into the dotfiles checkout. `jail.enable` (bubblewrap sandboxing) is also part of that module and is Linux-only besides, moot for this Darwin-only repo.
- Imperative (`.text`-owned) management of `~/.pi/agent/settings.json`. That file mixes interactive state pi persists at runtime (the saved `defaultProvider`/`defaultModel` from `/model`, `theme`, etc.), so it is symlinked out-of-store instead: pi's runtime writes land in the tracked `settings.json`, and the diff is committed to update the baseline. See "settings.json — Live-Editable Baseline" below.

## Why This Structure

`pi`'s dependency tree pulls in a package, nested several levels deep through one of its AI-provider integrations, that npm cannot install strictly from a lockfile: npm re-derives that package's requirements from the *actual* manifest embedded in its dependent's published tarball rather than trusting the lockfile, then falls back to a live registry fetch to reconcile the two. This reproduces with a plain `npm install` or `npm ci --offline`, independent of Nix, and survives editing the lockfile to remove the offending dependency entirely — so no lockfile-level fix is available. It specifically breaks `pkgs.importNpmLock.buildNodeModules` (the mechanism `modules/nodejs/node-tools/drv.nix` uses), because that mechanism reconstructs `node_modules` fully offline inside the build sandbox.

`github:lukasl-dev/pi.nix` avoids this by using plain `buildNpmPackage` with a precomputed `npmDepsHash` instead: the dependency-fetch step runs as a fixed-output derivation, which is allowed network access and is instead verified after the fact by content hash. That sidesteps the specific offline-reconstruction failure entirely. The flake also carries the source patches upstream `pi` needs to build outside its own monorepo tooling (workspace build-order fixes, vendored `models.generated.ts`/provider files, changelog URL rewrites) and stays current: `VERSION.json` is bumped by an automated daily cron job in that repo, tracking upstream `pi` releases within about a day. The exact pinned version lives in that `VERSION.json` (do not hardcode a pi version here); pull it forward in lockstep with upstream by running `nix flake update pi`.

The `~/.pi/agent/AGENTS.md` symlink (in `modules/ai-rules/home.nix`) relies on a real `pi` feature, not something `pi.nix` adds: `pi` reads that path as its global instruction file the same way it reads a project-level `AGENTS.md`/`CLAUDE.md`.

## models.json — Pointing pi at the Local Server

`~/.pi/agent/models.json` declares a single custom provider (`llamaswap`, id and URL from `modules/llm-server/catalog.json`, the same single source of truth `modules/opencode/home.nix` consumes) with the catalog's model list. This is the one declarative pi config file that is safe to own: unlike `settings.json` it holds no interactive state.

The provider is a custom `openai-completions` entry rather than pi's built-in `llama.cpp` provider. The built-in one targets a real llama.cpp *router* server (`--models-dir`, `/llama` load/unload, `--no-models-autoload`); llama-swap is not a router — it hot-swaps `llama-server` processes per request and has no router control endpoints. An explicit OpenAI-compatible provider with a fixed model list is the deterministic path, and mirrors how opencode already calls the same server.

`compat` mirrors the flags pi's built-in llama.cpp provider sets (`src/extensions/llama/provider.ts`): `supportsStore`/`supportsDeveloperRole`/`supportsReasoningEffort`/`supportsStrictMode` false, `supportsUsageInStreaming` true, `maxTokensField: "max_tokens"`. llama-swap forwards the request body unchanged to the spawned `llama-server`, so the same server constraints apply. `apiKey: "none"` is a dummy: llama-swap does not authenticate, but pi treats models as available only when the provider has an API key configured.

Models flagged `"thinking": true` in the catalog get `reasoning: true` plus `compat.thinkingFormat: "qwen-chat-template"` with `chatTemplateKwargs` (`enable_thinking` bound to pi's thinking level via `$var`/`thinking.enabled`, `preserve_thinking: true`) — the pi-documented way to drive thinking on a local Qwen chat template. Without the flag (Gemma models), no reasoning is enabled and the request is a plain system-role chat call.

Verified end-to-end against the live server (via `PI_CODING_AGENT_DIR` against a scratch dir): `pi --list-models` shows all catalog models with thinking correctly flagged, and `pi -p` print-mode requests reach llama-swap and return Qwen 3.6 output with `--thinking high`.

## DeepSeek via the Native `opencode` Provider

To use opencode zen's free DeepSeek models (e.g. `opencode/deepseek-v4-flash-free`) as pi's default model **with working tool calls**, the baseline points `defaultProvider` at pi's **built-in `opencode` provider** rather than at the `opencode-cli` bridge.

Why not the `opencode-cli` bridge (`opencode-pi` extension): that extension registers an `opencode-cli` provider that shells out to `opencode run`, denies opencode's native tools (bash/read/edit/...), and asks the model to emit `<pi_tool_call>{...}</pi_tool_call>` text markers which it reparses into pi tool calls. DeepSeek free models do not emit those markers — they emit opencode's native `tool_use` events (verified: `opencode run -m opencode/deepseek-v4-flash-free` produces `{"type":"tool_use","part":{"tool":"bash",...}}`). The bridge treats that as a hard error (`OpenCode attempted to use its disabled native tool (bash)`, `opencode-pi/src/index.ts`), so every real tool call fails. The bridge is inherently model-fragile: it only works for models that cooperate with the text-marker convention.

pi's built-in `opencode` provider instead talks the zen wire protocol directly at `https://opencode.ai/zen/v1` (`@earendil-works/pi-ai/dist/providers/data/opencode.json`, which lists `deepseek-v4-flash-free` with `api: "openai-completions"`, `reasoning: true`, zero cost) and runs through pi's native OpenAI-compatible tool-call pipeline — real `tool_calls`, no text markers. `pi-free` already wires this provider up via its built-in toggle (free mode), so no extra package is needed.

Constraint: unlike the `opencode run` CLI (which serves the free models with no account), the native `opencode` provider requires a **valid zen API key** — pi refuses a missing key (`No API key found for opencode`) and the gateway rejects a dummy one (`401: Invalid API key.`). The key must be provisioned via `/login opencode` (stored in `~/.pi/agent/auth.json`, a secret not managed by this repo) or the `OPENCODE_API_KEY` env var.

## settings.json — Live-Editable Baseline

`~/.pi/agent/settings.json` mixes declarative user preference (`theme`, `defaultThinkingLevel`, `enableSkillCommands`) with interactive state pi persists at runtime (`defaultProvider`/`defaultModel`, the `packages` list that `pi install` mutates). Because pi rewrites this file itself, it is **not** owned as Nix-generated `.text` content — that would clobber pi's runtime writes on every rebuild. Instead it is an out-of-store symlink to `modules/pi/settings.json` (tracked in the checkout), the same live-editable pattern as `~/.claude/settings.json` in `modules/claude/home.nix`.

Consequences:

- When pi writes `settings.json` (via `/model`, `pi config`, `pi install`), the change lands directly in the tracked `modules/pi/settings.json`. To persist it, commit that diff — the baseline then represents "intended state" rather than Nix-forced state.
- Rebuilds recreate the symlink to the tracked file but never overwrite its contents, so pi's runtime state is preserved across rebuilds (it is not rolled back).
- The saved `defaultProvider`/`defaultModel` only resolve to a working model once the matching provider is wired up; the committed baseline pins `opencode`/`opencode/deepseek-v4-flash-free` (a free opencode zen model), which requires a valid opencode zen API key — see "DeepSeek via the Native `opencode` Provider".

The `packages` list is committed in the same file. `pi install`-added packages should be committed deliberately; the baseline pins the currently intended set (including `npm:pi-free`). Note `pi list` may not enumerate every installed extension, so treat the committed `packages` list — not `pi list` output — as the source of truth, and drop an entry only when it is genuinely unwanted.

## Rejected Alternatives

- **`buildNpmPackage`/`importNpmLock` via `modules/nodejs/node-tools`**: blocked by the npm behavior described above.
- **`pnpm add --global` from a `home.activation` step** (mirroring `modules/herdr`'s imperative-installer pattern): worked and was implemented first, but was abandoned once `pi.nix` was found. It traded away Nix's hermeticity and Cachix caching, required network access on every `darwin-rebuild switch`, and needed an explicit `--ignore-scripts` decision to avoid running arbitrary install scripts with full user permissions outside any sandbox.
- **`node2nix`**: forbidden repository-wide — removed from nixpkgs and unmaintained.
- **`programs.pi.coding-agent.rules`**: works (verified: builds and injects the intended content via `--append-system-prompt`), but was rejected in favor of the plain `home.packages` + symlink approach above, to keep `pi` consistent with how every other agent's rules file is managed in this repo.
- **Built-in `llama.cpp` provider** (via `LLAMA_BASE_URL`/`/login llama.cpp`): targets a llama.cpp router server whose `/llama` model-loading control flow llama-swap cannot serve; see above.
- **`opencode-cli` bridge** (`opencode-pi` extension): shells out to `opencode run` and bridges pi tool calls via `<pi_tool_call>` text markers. Reachable its without any account (reusing the local opencode CLI's anonymous access to free models), but the text-marker convention is model-fragile — DeepSeek free models emit native opencode `tool_use` events instead, which the bridge hard-errors on, so tool calls failed. Superseded by the native `opencode` provider once a zen API key is available; see "DeepSeek via the Native `opencode` Provider".

## Constraints

- `pi.nix` pins its own `nixpkgs` (`nixos-unstable`) rather than following this repo's `nixpkgs` input, since its build carries upstream-specific patches tested against that pin. Left un-followed deliberately — forcing `.follows` risks breaking a build that was never tested against this repo's `nixpkgs-26.05`.
- Freshness tracks `pi.nix`'s own sync cadence (daily cron in that repo) plus whenever this repo runs `nix flake update` on the `pi` input — not continuous per-build "latest" like an imperative installer would give.
- `~/.pi/agent/AGENTS.md` only gets `rules.md`, not the topic-specific `rules/loop-engineering.md` — a real file can only symlink to one source, and `pi` has no directory-of-files convention like Claude's `~/.claude/rules/` to point at instead. This matches how Cursor is already handled in the same file.
- models.json's `baseUrl` is the tailnet hostname `http://llm.mac-mini-m4-pro.internal/v1`, so pi only talks to the local server when the tailnet DNS is reachable and `services.llm-server` is up (mac-mini-m4-pro). The file is generated on every host regardless of that enablement, same as the opencode config.
- The saved default in `settings.json` is now owned by this module as a live baseline (see "settings.json — Live-Editable Baseline"); it is initialized (via the symlink target) to `opencode`/`opencode/deepseek-v4-flash-free` (a free opencode zen model). pi may still overwrite it at runtime, but rebuilds no longer roll it back and the diff is commit-able.
