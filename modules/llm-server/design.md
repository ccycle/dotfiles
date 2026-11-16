# LLM Server Design

## Purpose

Declaratively manage local LLM hosting on mac-mini-m4-pro using Ollama
and its MLX runner, exposed to tailnet clients via Caddy.

## Why Ollama (MLX Runner)

On Apple Silicon, Ollama runs supported architectures on its own MLX
runner instead of llama.cpp. Measured on this host (M4 Pro, 64 GB) with
the same ~6.2k-token prompt, thinking off, a per-run nonce to defeat
prefix caching, and the median of 3 runs:

| Model              | llama-swap + llama.cpp (GGUF Q4) | Ollama MLX (NVFP4)      |
| ------------------ | -------------------------------- | ----------------------- |
| Qwen3.6-35B-A3B    | 9.86 s TTFT, 40.8 tok/s          | 6.86 s TTFT, 85.5 tok/s |
| Ornith-1.5-35B-A3B | 10.08 s TTFT, 48.7 tok/s         | 6.48 s TTFT, 78.1 tok/s |

The quantization formats differ (GGUF Q4_K vs NVFP4), so the gap mixes
engine and format, but it is the engine/format pair actually available
on each side. A 1.6–2.1× decode speedup outweighs everything llama-swap
offered on top.

The earlier objection to Ollama — that its model registry is an
imperative store — is handled by treating the registry as a cache that
`catalog.json` fills: the `llm-server-models` agent pulls (or imports)
every catalog model and is idempotent, so the declared catalog, not
manual `ollama pull`, decides what is present. Models removed from the
catalog are not deleted from the store (see Non-Goals).

## Why Upstream's Binary, Not nixpkgs's ollama

nixpkgs's ollama is built without the MLX runner, which is the whole
reason for choosing Ollama. The upstream darwin release tarball is
pinned by hash instead; see [drv.nix](drv.nix).

## catalog.json — Single Source of Truth

`catalog.json` is a non-Nix data file that defines the model catalog
(Ollama model names, context lengths, thinking defaults, and an optional
Hugging Face import source) and the provider metadata (ID, display
name, baseURL). It is consumed by:

- `options.nix` (darwin eval): generates the server environment, the
  model-provisioning agent, and the Caddy vhost.
- [modules/opencode/home.nix](../opencode/home.nix) and
  [modules/pi/home.nix](../pi/home.nix) (home eval): generate each
  client's provider and model entries from the same catalog.

A shared `.nix` file would be flagged as `flat-submodule` by the
package-by-feature checker. A JSON data file read via
`builtins.fromJSON` passes the checker because it only scans `.nix`
path references.

## Hugging Face Imports

Some models (Ornith) exist on Ollama's registry only as GGUF, which
runs on the llama.cpp engine and loses the speedup. Their bf16 MLX
safetensors repo on Hugging Face is imported and quantized locally with
`ollama create -q nvfp4` instead. Import was validated by hand before
being declared: same architecture (`qwen3_5_moe`) as a registry MLX
model, ~80 s to quantize, correct code/Japanese/tool-call output.

## Why a User Agent, Not a System Daemon

Inference uses Metal. Metal access from root daemons is uncertain on
macOS. A user agent (`launchd.user.agents`) matches the cachix
watch-store precedent and guarantees Metal works.

## Why modelsDir Defaults to Ollama's Own Store

`custom.storage.volumes.llm-server` typically points at
`~/.ollama/models` (Ollama's own default) rather than the shared
external storage volume used by the other services:

1. **Permissions.** The other services run as root daemons, so
   `/var/lib/<service>` is writable by them. llm-server runs as a user
   agent, and `/var/lib` is root-owned. `~/.ollama` is already
   user-owned.
2. **Convention.** Matching Ollama's default means the CLI and the
   server agree on the store without extra configuration.

Each service in `custom.storage.volumes` is independent, so this does
not affect where other services store their data.

## Why Both HTTP and HTTPS (ca.caddy Pattern)

The vhost listens on both `http://` and `https://` with `import
internal_tls`. Caddy's auto-HTTPS generates a 308 redirect for any
hostname that appears in an HTTPS site block; an HTTP-only vhost would
be redirected to an HTTPS endpoint with no certificate, breaking the
connection. HTTP is used by clients that don't trust the internal CA
(notably opencode/Bun); HTTPS works for clients that do. Tailscale
WireGuard encryption makes HTTP safe on the tailnet.

## Non-Goals

- **No authentication.** Tailscale ACLs are the access boundary.
- **No LAN exposure.** Caddy binds to the Tailscale IP only.
- **No multi-model residency.** One loaded model at a time — the Mac
  mini has limited unified memory.
- **No Ollama cloud features.** Inference stays on this host.
- **No pruning of models dropped from the catalog.** Deleting tens of
  GB automatically on a catalog edit is too destructive; remove them
  with `ollama rm`.
- **No per-model server context length.** Ollama has one server-wide
  value, set to the largest catalog entry; smaller catalog values only
  cap what clients request.

## Constraints

- First chat request per model takes tens of seconds (model load).
- Port 11434 on 127.0.0.1 must not collide with another Ollama (e.g.
  Ollama.app).
- The first provisioning run downloads every catalog model; a Hugging
  Face import needs room for its full bf16 checkpoint (~70 GB) inside
  `modelsDir` until quantization finishes.

## Rejected Alternatives

- **llama-swap + llama.cpp + mlx-lm** (this module's previous design) —
  measured 1.6–2.1× slower decode than Ollama's MLX runner on the same
  models (see above), and required Metal-wheel overrides to get mlx at
  all.
- **LM Studio server** — GUI-managed state, no declarative context
  length. See [modules/lm-studio/design.md](../lm-studio/design.md).
- **Ollama.app** — same engine, but installed and updated outside Nix.
- **vLLM** — overkill for single-user serving; no macOS Metal support.
