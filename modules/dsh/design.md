# dsh Design

## Purpose

Install the latest DeepSeek Harness CLI (`dsh`) from npm, built by Nix against this repository's nixpkgs Node, and point its model routing at the local llm-server.

## Non-Goals

- Managing dsh profiles, plugins, sessions, settings, or credentials under `~/.dsh`; only the home-level patch is owned here, and the app keeps the rest.
- Exposing dsh's web UI as a service; it is launched on demand like any CLI.
- Tracking a specific upstream source revision; the npm lockfile is the pin.

## Why This Structure

Recent dsh releases read Node internals through a native addon that pattern-matches Node's machine code and refuses nixpkgs builds of Node.
Older releases, and two of dsh's own packages still today, load the same internals with `--expose-internals` instead.
The package therefore replaces that addon with a small shim and launches Node with that flag, so the whole process uses the path upstream already supports.
That needs a per-package wrapper flag and a patched dependency, which is why dsh lives in its own module instead of the shared node-tools package.

Model routing goes into the home-level patch because it outranks every profile's patch and dsh's config editor never writes it.

## Rejected Alternatives

- **[Samuka007/dsh-nix](https://github.com/Samuka007/dsh-nix):** builds from source and works, but pins an old pre-addon release; bumping it reintroduces the addon failure.
- **Plain npm package without the shim:** builds, but every profile fails at startup on any nixpkgs Node, stable or unstable.
- **Official upstream Node binary:** not verified, and it would bypass the nixpkgs Node every other tool here uses.
- **Rebuilding Node without frame pointers:** a full uncached Node build to satisfy one addon's pattern match.
- **`apiKeyEnv` with a dummy key:** works on current releases, but requires exporting a fake variable into every shell; an `Authorization` header keeps the workaround inside the patch.

## Constraints

- On each dsh bump, re-check that the addon is still only used for the internal modules `require()` can reach under `--expose-internals`; a new addon entry point would bypass the shim.
- The patch only takes effect while the llm-server is reachable on the tailnet, the same as the pi and opencode configs.
