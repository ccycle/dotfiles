# Git Module Design

## Purpose

Provide a consistent Git configuration across all machines, with credential management that works in both GUI and headless (SSH) sessions.

## Credential Management Strategy

There are two deliberately separate HTTPS authentication paths, split by who is pushing.

**Human pushes** use `git-credential-oauth` (`credential.helper = [ "osxkeychain" "oauth -device" ]`), an OAuth credential helper that stores tokens (including refresh tokens, on Git ≥ 2.45) in the macOS keychain and falls back to device flow only when no valid token is cached.
Device flow displays a URL and a one-time code in the terminal; the user completes authentication on any device with a browser.
The `-device` flag avoids the browser-launch requirement that breaks in headless SSH sessions.
The interactive device-flow step also acts as an intentional human-in-the-loop gate for first-time or expired auth: full-privilege pushes always require a human to have completed authentication at some point, never a bare static token.

**Agent pushes** go exclusively through the safe-push wrapper, which authenticates with a fine-grained PAT (selected repositories only, contents read/write, expiring) stored via sops-nix.
The security boundary for agents is the token's scope plus server-side branch rulesets — not client-side command pattern matching, which a shell-capable agent can route around.
The wrapper constrains what can be expressed (current branch to origin only, no force/delete/refspec, github.com host pinned) for accident prevention on top of that boundary.
Dangerous irreversible operations (history rewrite, branch deletion on the default branch) are blocked by GitHub rulesets regardless of which credential is used.

## Token Lifecycle

Fine-grained PATs must be created through the GitHub web UI — there is no API path for it — so rotation cannot be fully automated.
The rotation workflow (`.agents/skills/safe-push-credentials`) treats this as intentional rather than a gap to close: forcing a human into the token-creation step reintroduces the same human-in-the-loop property the device flow gives the human path, at the moment the strongest privilege change happens.
Expiration monitoring is kept separate from rotation: a scheduled check surfaces the token's remaining lifetime early enough to rotate ahead of time, rather than rotation being triggered reactively by a failed push.

## Audit Logging

`git-safe-push` writes a local, append-only log of every invocation (attempted, refused, succeeded, failed), including branch and remote host but never the token.
This is deliberately not a security control — per the Credential Management Strategy above, the actual boundary is token scope plus server-side rulesets, not anything client-side.
The log exists so anomalous local usage (e.g. repeated refused attempts against a protected branch) is visible on its own, independent of whatever GitHub's server-side records show.

## Non-Goals

- SSH transport for Git remotes.
  HTTPS is the standard; SSH URLs add a transport-level auth path to maintain.
- GUI-based OAuth flow.
  Disabled globally because the primary development environment is SSH into macOS.
- Non-interactive full-privilege pushes.
  Only the scoped agent PAT works without a human; anything beyond its scope requires the device-flow gate.

## Rejected Alternatives

- **`osxkeychain` credential helper with manual PAT**: simpler, but requires the user to generate, rotate, and store PATs manually.
  The `oauth` helper automates the full token lifecycle for the human path; `osxkeychain` is kept only as the storage layer underneath it, not as a manual-PAT target.
- **SSH URLs for Git remotes**: would bypass credential helpers entirely, but introduces a parallel authentication mechanism at the transport level.
- **Caching the human OAuth token for non-interactive agent use**: would let agents push, but with the human's full-privilege token and no scope limit, and it removes the device-flow gate for everyone.
- **Reusing the gh CLI OAuth token for agent pushes**: the token is broad-scoped (all repos, full `repo` scope); a fine-grained PAT bounds the blast radius per repository and permission.
  For the same reason, gh's git credential helper stays disabled.
- **Git Credential Manager (GCM)**: used previously for the human path.
  Replaced because the git credential protocol has no attribute for GCM to persist an OAuth refresh token, so it fell back to a full device-flow prompt more often than the design intended (compounded by known upstream macOS keychain reuse bugs, e.g. git-ecosystem/git-credential-manager#1157 and #2079).
  `git-credential-oauth` supports storing refresh tokens under Git ≥ 2.45, so the device-flow prompt now recurs only when the refresh token itself expires, not on every push.
