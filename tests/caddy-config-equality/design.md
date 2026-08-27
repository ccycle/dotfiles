# Caddy Config Equality Test Design

## Purpose

Verify that the template-based Caddy configuration (post-refactor)
generates identical output to the previous inline Nix version. This is a
regression test ensuring the refactor did not change any generated
configuration files.

## Why This Test Exists

The refactor in commit `0a4d985` moved Caddy configuration from inline
Nix string interpolation to template files with placeholder substitution.
The generated output should be byte-for-byte identical. This test catches
any divergence introduced by:

- Incorrect template content (missing or extra whitespace, comments)
- Wrong placeholder names or substitution logic
- Differences in Nix string interpolation vs `builtins.replaceStrings`

## What Is Compared

| File | Old Mechanism | New Mechanism |
|------|---------------|---------------|
| Caddyfile | Inline Nix `${hostName}` | Template `__HOSTNAME__` |
| opencloud.caddy | Inline Nix `${domain}` | Template `__DOMAIN__` |
| immich.caddy | Inline Nix `${domain}` | Template `__DOMAIN__` |
| index.caddy | Inline Nix `${domain}` + `${indexHtml}` | Template `__DOMAIN__` + `__INDEX_HTML__` |
| attic.caddy | Inline Nix `${domain}` | Template `__DOMAIN__` |
| ca.caddy | Inline Nix `${domain}` + `${hostName}` + `${caHtml}` | Template `__DOMAIN__` + `__HOSTNAME__` + `__CA_HTML__` |

## How It Works

1. Define the old inline Nix strings directly (extracted from `HEAD~2`,
   before the refactor commit)
2. Apply the new template substitution using `builtins.replaceStrings`
   with the same `hostName` and `domain` values
3. Compare each pair with `==`
4. Fail if any pair differs

The test uses a fixed `hostName = "test-host"` so results are
deterministic and independent of the actual machine.

## Non-Goals

- Testing that Caddy actually starts with the generated config (covered
  by existing smoke tests and E2E tests)
- Testing template substitution for values that change per host (the
  test uses a fixed hostName)
- Testing the `caddyEtcHash` or launchd integration (orthogonal to
  config generation)

## Constraints

- The old inline strings are hardcoded in this test file, copied from
  `HEAD~2:modules/caddy/darwin.nix`. If the original inline strings are
  modified in the future (unlikely, since they've been replaced), this
  test would need updating.
- The test depends on `ca.html` and `index.html` being unchanged. If
  those files are modified, both the old and new versions will pick up
  the change, so the comparison remains valid.
