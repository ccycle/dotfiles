# Storage Design

## Purpose

Let each service declare where its data lives (`custom.storage.volumes.<service>`)
without hardcoding a path in tracked Nix files. The actual value comes from
`.local/storage/flake.nix`, a gitignored, per-machine override.

## Why Per-Service, Not a Single Shared Root

An earlier version exposed one `custom.storage.volumeRoot` used by every
service. That broke down once a service needed a different placement than
the rest — e.g. llm-server's model cache belongs on the internal disk
(`~/Library/Caches/llama.cpp`, matching llama.cpp's own default) while
forgejo/immich/gitlab/monitoring/opencloud share an external volume. Moving
to `custom.storage.volumes` (an attrset keyed by service name) lets each
service opt into its own path independently.

## Why No Fallback/Default Volume

`custom.storage.volumes` has no "default" entry that unset services fall
back to. Every service consuming it asserts its own key is present. A
fallback would silently place a newly-enabled service on whatever volume
happens to be the default, which is exactly the kind of unexamined
placement decision per-service storage exists to prevent — enabling a
service should force a conscious choice of where its data goes.

## Why mountPoint Is Derived, Not a Separate Option

Each service still has a `mountPoint` option (used by `waitForMount` to
block launchd startup until an external volume is actually mounted — see
`utils/waitForMount.nix`). Rather than asking the user to set `volumes.X`
and `mountPoint.X` separately (and keep them in sync), each service's
`darwin.nix` derives `mountPoint` from its own volume path, using
`hasPrefix "/Volumes/" vol` as an external-volume heuristic:

```nix
services.X.mountPoint = mkIf (hasPrefix "/Volumes/" vol) (mkDefault vol);
```

This is `mkIf`, not an `if/else` with an empty-string branch: when `vol`
is not under `/Volumes/`, the expression contributes no override at all,
and `mountPoint` keeps its own option default (`""`, meaning "don't
wait"). Nothing is set to a fallback value — the option simply has no
definition from this module when there's no volume to wait for.

## Why the Missing-Volume Check Is a Warning, Not an Assertion

`utils/warnIfVolumeMissing.nix` wraps each service's `vol` and prints an
eval-time warning (via `lib.warn`, visible directly in `darwin-rebuild
switch` output) if the path doesn't exist — without failing the build.

A hard assertion was considered and rejected. `builtins.pathExists`
cannot distinguish a typo (a path that will never exist) from a
removable volume that is simply not attached at rebuild time (which
`waitForMount`, above, already treats as a normal, self-resolving
state). An assertion aborts the entire system evaluation on failure —
turning "the SSD happens to be unplugged right now" into "the whole
`darwin-rebuild switch` fails, including unrelated changes to other
modules." A warning surfaces the same signal (visible immediately,
without needing to check launchd logs) without that collateral damage.
