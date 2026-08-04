# LLM Server Design

## Purpose

Declaratively manage local LLM hosting on mac-mini-m4-pro using
llama-cpp and llama-swap, exposed to tailnet clients via Caddy.

## Why llama-swap + llama-cpp

LM Studio's server state (per-model context length, loaded models,
model IDs) is GUI-managed and not declaratively controllable. This
caused: (a) `n_keep > n_ctx` crashes when opencode's ~14k-token system
prompt hit the default 4096 context length, and (b) model-ID drift
between the hand-written opencode.json and the live server.

Ollama was rejected because its model registry is another imperative
store — pulling models and managing Modelfiles is stateful in the same
way LM Studio's GUI is.

llama-swap is an OpenAI-compatible proxy that hot-swaps llama-server
processes per the `model` field in the request. Combined with
llama-cpp's `--ctx-size` CLI flag, every parameter that matters
(model file, context length, GPU layers) is a declarative config value.

## catalog.json — Single Source of Truth

`catalog.json` is a non-Nix data file that defines the model catalog
(IDs, GGUF download URLs, context lengths) and the provider metadata
(ID, display name, baseURL). It is consumed by:

- `options.nix` (darwin eval): generates the llama-swap config.yaml,
  the launchd agent script (with download logic), and the Caddy vhost.
- `modules/opencode/home.nix` (home eval): generates opencode.json
  with provider and model entries derived from the same catalog.

A shared `.nix` file would be flagged as `flat-submodule` by the
package-by-feature checker. A JSON data file read via
`builtins.fromJSON` passes the checker because it only scans `.nix`
path references.

## Why a User Agent, Not a System Daemon

llama-server uses Metal for GPU inference. Metal access from root
daemons is uncertain on macOS. A user agent (`launchd.user.agents`)
matches the cachix watch-store precedent and guarantees Metal works.

Logs go to `/var/tmp/llm-server.log` (user-writable, survives reboot).

## Download-on-First-Start

GGUF files (tens of GB) are downloaded on the first launchd start, not
at Nix build time. This avoids bloating the Nix store and means adding
a model is an edit to catalog.json + rebuild + wait for download. Failed
downloads cause the script to exit; KeepAlive retries.

## Why modelsDir Defaults to llama.cpp's Own Cache Path

`custom.storage.volumes.llm-server` typically points at
`~/Library/Caches/llama.cpp` (llama.cpp's own default cache directory on
macOS) rather than the shared external storage volume used by the other
services. Two reasons:

1. **Permissions.** The other services run as root daemons, so
   `/var/lib/<service>` is writable by them. llm-server runs as a user
   agent (see above), and `/var/lib` is root-owned — pointing modelsDir
   there would require a one-time manual `chown`. `~/Library/Caches` is
   already user-owned.
2. **Convention.** Matching llama.cpp's own default means `modelsDir`
   holds exactly the files llama.cpp itself would put there, with no
   extra subdirectory invented by this module.

Because each service in `custom.storage.volumes` is independent, this
does not affect where forgejo/immich/gitlab/monitoring/opencloud store
their data — they keep using the shared external volume.

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
- **No multi-model residency.** llama-swap `groups` (concurrent model
  loading) is rejected — the Mac mini has limited unified memory and
  llama-swap already handles model swapping.
- **No Nix-store model storage.** GGUF files are too large for the
  store; they live outside it, in `modelsDir`.

## Constraints

- First chat request per model takes up to a minute (model load).
- Port 8880 on 127.0.0.1 must not collide with other services.
- The user agent must have write access to `modelsDir`. If
  `custom.storage.volumes.llm-server` is pointed at an external volume
  instead of the default `~/Library/Caches/llama.cpp`, that volume must
  be mounted and writable before launchd starts the agent.

## Rejected Alternatives

- **LM Studio server** — GUI-managed state, no declarative context
  length. See `modules/lm-studio/design.md`.
- **Ollama** — imperative model registry (pull/create/Modelfile).
- **vLLM** — overkill for single-user serving; no macOS Metal support.
- **Nix-store GGUF downloads** — 50+ GB fixed-output derivations would
  bloat the store and slow garbage collection.
