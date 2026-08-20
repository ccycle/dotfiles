# MTPLX Design

## Purpose

Serve MLX-format models with speculative decoding (native-MTP Qwen
checkpoints, or Gemma checkpoints paired with an external drafter) on
Apple Silicon via MTPLX, a third-party runtime that llama.cpp/llama-swap
cannot run. Exposes an OpenAI-compatible endpoint to opencode, alongside
the existing `llm-server` (llama-swap/GGUF) module.

## Non-Goals

- **No Nix-native packaging of the `mtplx` runtime.** It is installed
  imperatively via a launchd-run install script, not `buildPythonApplication`.
- **No concurrent multi-model residency.** Each catalog model gets its own
  launchd job, but all of them bind the same port, so only one can actually
  be running at a time — see "Why One Job Per Model, Sharing One Port".
- **No idle-unload / automatic memory reclamation.** The served model stays
  resident in unified memory for the lifetime of the process.
- **No authentication and no LAN exposure**, matching `llm-server`: Tailscale
  ACLs are the access boundary, Caddy binds to the tailnet interface only.
- **No integration with `custom.storage.volumes`.** Model weights live
  wherever MTPLX's own cache defaults to, not on the shared external volume.

## Why a Separate Module From `llm-server`

`llm-server` runs llama-swap, which spawns and swaps `llama-server`
subprocesses per request — every model it serves goes through the same
GGUF/llama.cpp code path, and its design explicitly rejects holding more
than one model resident at once. MTPLX is architecturally a different
kind of service: a single always-on OpenAI-compatible daemon with its own
internal model/session management, not a subprocess llama-swap can spawn
per-request the way it spawns `llama-server -m <file>`. Folding it into
`llm-server` would mean stretching that module's config schema (GGUF file
URLs, llama.cpp CLI flags) to cover a fundamentally different runtime.
Keeping it a sibling module keeps both config schemas honest and lets each
service's process-lifecycle model (swap-on-demand vs. always-on) stay
independent.

`opencode`'s config generation reads both modules' `catalog.json` and
merges them into separate providers, so this split is invisible to the
client — it just sees two OpenAI-compatible providers instead of one.

## Why an Install Script Instead of Nix Packaging

Nix-native packaging (`buildPythonApplication` from the PyPI source) was
the first approach attempted, and was abandoned after prototyping surfaced
three compounding problems:

1. **Runtime JIT compilation.** MTPLX's paged-attention Metal kernel is not
   built at package-build time; it is compiled by shelling out to
   `clang++` the first time the extension is imported, caching the result
   under the invoking user's home directory. This works fine on a real
   machine with Xcode Command Line Tools installed, but it means the
   Nix-packaged binary still depends on external, un-sandboxed compiler
   invocation at runtime — packaging it in Nix would not have bought the
   reproducibility Nix packaging usually provides.
2. **Version skew with a documented performance cost.** nixpkgs' `mlx`
   package trails the exact minimum version MTPLX pins, and the two
   versions are not interchangeable — MTPLX's own release notes record a
   measured throughput regression on the older version for long
   generations. Overriding nixpkgs' `mlx` to a newer version was possible
   in principle but adds an independent, ongoing packaging burden (tracking
   a fast-moving upstream, verifying each bump still builds under nixpkgs'
   toolchain) on top of problem 1.
3. **No packaging shortcut available.** The upstream Homebrew tap is a
   personal third-party tap, not part of the official homebrew-cask index
   this repo's `brew-nix` integration packages automatically — so there is
   no existing `brewCasks.<name>` derivation to build on. Inspecting the
   tap's own formula showed it does not build a binary either; it lazily
   `pip install`s into a venv on first run, which is no more reproducible
   than packaging the wheel directly. The signed DMG distribution was
   inspected for the same reason and ruled out below.

Given all three distribution channels (PyPI wheel, Homebrew tap, DMG)
bottom out in the same Python package with the same runtime JIT-compile
step, the install script does the same thing a from-scratch Nix derivation
would have had to do at runtime anyway — download, extract, `pip install`
— just without pretending it is a reproducible build. It follows the same
download-on-first-start shape as `llm-server`'s GGUF fetch: a launchd
script that checks whether the runtime is already installed and only pays
the download/install cost once.

## Why the DMG, Not the Wheel Directly

The DMG bundles a self-contained Python runtime; the raw wheel does not
carry a Python interpreter at all, so using it directly would require a
system or nixpkgs Python that still needs `pip install`ing every other
dependency (`mlx`, `mlx-lm`, `fastapi`, ...) against a matching pin. The
DMG's bundled runtime installs the same wheel on first launch and resolves
those dependencies itself, which is exactly the behavior the install
script wants headlessly. Only the runtime and the wheel are extracted from
the DMG; the GUI application shell, its Sparkle auto-updater, and the
interactive first-run hardware wizard are discarded — this module never
launches the GUI binary.

## Why No Auto-Start (No `KeepAlive`/`RunAtLoad`)

MTPLX does not expose an idle-unload mechanism for the primary chat model
(unlike its embedding/reranker endpoints, which do support one) — once
loaded, the model stays resident for the life of the process. Auto-starting
it on every boot/login would mean permanently reserving a large share of
the host's unified memory even when nothing is using it, on a machine that
also runs several other memory-hungry services. The launchd agent is
registered but left dormant; it is started on demand.

## Why One Job Per Model, Sharing One Port

The catalog can list more than one MTPLX-servable model (e.g. a native-MTP
Qwen checkpoint and a Gemma checkpoint with an external drafter), each
exposed to opencode as its own selectable model under the same provider.
The host does not have memory headroom to hold two of these resident at
once on top of everything else it already runs — live measurement during
review showed the machine at 62/64 GB used with swap nearly exhausted even
with only one MTPLX model loaded. Rather than track "is another one
already running?" as explicit state, every model's launchd job binds the
same fixed port: starting a second one while the first is still up fails
immediately on a bind conflict instead of silently doubling memory use.
This makes the mutual exclusion a property of the OS's socket layer, not
something this module has to detect and enforce itself. The tradeoff:
opencode's model picker doesn't know which one is actually running, so
picking the wrong one just times out — the operator has to switch with the
matching `mtplx-start-<shortId>` alias first.

## Workload Split With `llm-server` Given the Agentic-Cache Gap

Despite the prefill/session-cache limitation recorded under Constraints,
MTPLX is being kept rather than removed. Its architectural advantages
(native speculative decoding, MLX-optimized throughput) still apply to
workloads that do not depend on cross-turn cache reuse: single-shot
completions, and any client issuing one self-contained prompt per request
rather than an evolving multi-turn session.

Opencode and other agent-style clients default to `llm-server`
(llama-swap/GGUF) instead, because agentic prefill-reuse expectations are
exactly what the cache gap breaks — every agent turn would otherwise
re-pay the full-context prefill cost that `llm-server`'s cache avoids.
This routing lives in `opencode`'s generated config as a workload-level
choice, not something the two providers negotiate at runtime.

This split is provisional, tracking the upstream cache issue rather than
reflecting a permanent architectural judgment. If the issue is resolved
upstream, MTPLX becomes a candidate for agentic workloads again, since its
lower per-token latency would then apply without paying the reprefill
penalty on every turn.

## Rejected Alternatives

- **`buildPythonApplication` (pure Nix).** See above — abandoned due to
  runtime JIT compilation, an outdated pinned `mlx` version with a
  documented performance regression, and no upstream shortcut to avoid
  rebuilding both from scratch.
- **`brew-nix` (this repo's existing cask-packaging flake).** Only
  packages casks from the official homebrew-cask index; MTPLX's Homebrew
  distribution is a personal third-party tap outside that index, so there
  is nothing for it to package.
- **A live Homebrew tap (`homebrew.taps`/`homebrew.brews`).** Would add an
  imperative, external-state dependency with no precedent in this repo,
  for no benefit over the install script — the tap's own formula reduces
  to the same `pip install` the script already does.
- **Folding MTPLX into `llm-server`'s `catalog.json`/llama-swap config.**
  See "Why a Separate Module" above.
- **Running the model under llama-swap's process-spawn model.** MTPLX
  does take a `--model` flag, so this was technically possible, but the
  chosen design runs MTPLX as a standalone always-on service instead,
  keeping its lifecycle independent of llama-swap's swap-on-demand model.

## Constraints

- Requires macOS with Xcode Command Line Tools installed (for the runtime
  `clang++` JIT compile of the Metal extension); this is assumed already
  present, as it is a common prerequisite for Nix/Homebrew on this host.
- Only enabled on `mac-mini-m4-pro`; the served model's peak memory
  footprint is large relative to the host's unified memory when other
  services are also running.
- The install step needs network access and a writable home directory;
  it is not sandboxed the way a Nix build would be.
- MTPLX's cross-turn session/prefill cache does not currently work for
  agent-style clients (opencode included): commits are silently refused or
  dropped, so every turn re-prefills the full context rather than reusing
  the previous turn's KV state. This is a known, open upstream issue as of
  2.8.3 (youssofal/MTPLX#291, #290, #278), not a configuration mistake on
  our side. `--preserve-thinking off` (set via `extraFlags` in
  `catalog.json`) is the workaround #291 recommends for Qwen 3.8's specific
  mechanism, but it did not resolve the symptom for Gemma 4 in testing here
  (`bytes`/`entries`/`writes_enqueued` all stayed 0 across a two-turn
  session) — the flag is kept because it's a harmless no-op otherwise, not
  because it's a confirmed fix.
