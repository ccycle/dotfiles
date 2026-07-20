# Git Module Design

## Purpose

Provide a consistent Git configuration across all machines, with credential management that works in both GUI and headless (SSH) sessions.

## Credential Management Strategy

All HTTPS remote authentication uses Git Credential Manager (GCM) with OAuth device flow.

Device flow displays a URL and a one-time code in the terminal; the user completes authentication on any device with a browser.
This avoids the browser-launch requirement that breaks in headless SSH sessions.
GCM handles token storage (via macOS Keychain) and automatic refresh, so no manual PAT management is needed.

## Non-Goals

- SSH transport for Git remotes.
  HTTPS with GCM is the standard; SSH URLs add a second auth path to maintain.
- GUI-based OAuth flow.
  Disabled globally because the primary development environment is SSH into macOS.

## Rejected Alternatives

- **`osxkeychain` credential helper with manual PAT**: simpler, but requires the user to generate, rotate, and store PATs manually.
  GCM automates the full token lifecycle.
- **SSH URLs for Git remotes**: would bypass credential helpers entirely, but introduces a parallel authentication mechanism.
  Keeping a single HTTPS-based path is simpler to reason about.
