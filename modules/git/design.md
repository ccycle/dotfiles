# Git Module Design

## Purpose

Provide a consistent Git configuration across all machines, with credential management that works in both GUI and headless (SSH) sessions.

## Credential Management Strategy

There are two deliberately separate HTTPS authentication paths, split by who is pushing.

**Human pushes** use Git Credential Manager (GCM) with OAuth device flow.
Device flow displays a URL and a one-time code in the terminal; the user completes authentication on any device with a browser.
This avoids the browser-launch requirement that breaks in headless SSH sessions.
The interactive OTP step also acts as an intentional human-in-the-loop gate: full-privilege pushes always require a human at the keyboard.

**Agent pushes** go exclusively through the safe-push wrapper, which authenticates with a fine-grained PAT (selected repositories only, contents read/write, expiring) stored via sops-nix.
The security boundary for agents is the token's scope plus server-side branch rulesets — not client-side command pattern matching, which a shell-capable agent can route around.
The wrapper constrains what can be expressed (current branch to origin only, no force/delete/refspec, github.com host pinned) for accident prevention on top of that boundary.
Dangerous irreversible operations (history rewrite, branch deletion on the default branch) are blocked by GitHub rulesets regardless of which credential is used.

## Non-Goals

- SSH transport for Git remotes.
  HTTPS is the standard; SSH URLs add a transport-level auth path to maintain.
- GUI-based OAuth flow.
  Disabled globally because the primary development environment is SSH into macOS.
- Non-interactive full-privilege pushes.
  Only the scoped agent PAT works without a human; anything beyond its scope requires the device-flow gate.

## Rejected Alternatives

- **`osxkeychain` credential helper with manual PAT**: simpler, but requires the user to generate, rotate, and store PATs manually.
  GCM automates the full token lifecycle for the human path.
- **SSH URLs for Git remotes**: would bypass credential helpers entirely, but introduces a parallel authentication mechanism at the transport level.
- **Caching the GCM token for non-interactive agent use**: would let agents push, but with the human's full-privilege token and no scope limit, and it removes the OTP gate for everyone.
- **Reusing the gh CLI OAuth token for agent pushes**: the token is broad-scoped (all repos, full `repo` scope); a fine-grained PAT bounds the blast radius per repository and permission.
  For the same reason, gh's git credential helper stays disabled.
