# AltServer Design

## Purpose

Keeps free-tier iOS code-signing certificates alive on real hardware so self-built and forked-OSS apps
can run on the user's iPhone without paying for an Apple Developer Program membership. Runs on
`mac-mini-m4-pro` only, and only re-signs apps while the iPhone is on the same physical Wi-Fi network as
that Mac.

## Why AltServer, Not SideStore

SideStore (and its on-device refresh) needs anisette data — machine-identity information that only real
Apple hardware can produce natively. On iOS, SideStore gets this from an anisette server that emulates a
Mac. Community anisette servers pool many users' Apple ID logins through one emulated machine identity,
which is a documented account-lock trigger. Self-hosting an anisette server avoids the pooling risk but
introduces a different problem: SideStore's on-device refresh needs its own local VPN (StosVPN), and iOS
only allows one active personal VPN at a time, so the existing Tailscale connection gets dropped for the
duration of every refresh. A self-hosted anisette server living behind Tailscale would then be
unreachable at exactly the moment it's needed — confirmed as a real, unresolved conflict in
[SideStore/SideStore#475](https://github.com/SideStore/SideStore/issues/475), closed as not planned.
Making the anisette server reachable independent of Tailscale means exposing it to the public internet.

AltServer sidesteps all of this because it runs on genuine Mac hardware: it uses Apple's real frameworks
to get machine-identity data, so no anisette server, no on-device VPN trick, and no account-lock or
exposure trade-off exist in the first place. The cost is that AltServer's Wi-Fi refresh only works when
the iPhone is on the literal same LAN as the Mac (confirmed: Tailscale cannot bridge this gap for
AltServer either, per reports on
[altstoreio/AltStore#1236](https://github.com/altstoreio/AltStore/issues/1236)) — accepted in exchange
for not depending on any external service or exposing anything beyond the existing Tailscale boundary.

## Why brew-nix, Not a Cask-to-Nix-Derivation Converter

Tools like nix-casks/brew-nix-alternative projects statically convert Homebrew Cask definitions into pure
Nix derivations without running the Cask's real installer logic. AltServer registers a Network Extension
and needs to run as a GUI menu-bar app — exactly the kind of Cask where a skipped `postflight` step would
fail silently. This repo already depends on brew-nix (`modules/brew-nix/darwin.nix`) for other Casks, and
brew-nix bootstraps a real Homebrew install via Nix rather than reimplementing the installer, so it's
used here too for reliability.

## Why a Per-User LaunchAgent, Not a System Daemon

AltServer is a menu-bar GUI app and needs WindowServer access, which `launchd.daemons.*` (running as
root) cannot provide — same reasoning already applied in `modules/desktoppr/darwin.nix`. It runs as
`launchd.user.agents.altserver` instead.

## Why There's No Apple ID Secret in This Module

Both the background refresh and `build-and-sign.sh`'s scripted install operate on whatever Apple ID is
signed into AltServer's own Preferences/Keychain after a one-time manual GUI login — confirmed by
inspecting the built binary's strings: it exposes no `-a`/`-p`-style Apple-ID/password flags, only
`--udid <device-udid> <ipa-path>`. There is therefore nothing for a `sops` secret to hold; no module
secrets.yaml exists here. (Public AltServer/AltStore documentation describes `-a`/`-p` flags for scripted
credential-based sign-in; this build's actual binary does not have them, so don't rely on that
documentation for this module.)

## Non-Goals

- **Away-from-home real-device verification.** Deliberately dropped in favor of iOS Simulator + XCUITest
  for day-to-day iteration; only the periodic re-sign, when at home, touches a real device.
- **Hosting an IPA/source distribution endpoint.** Not needed since AltServer installs directly from the
  Mac to the paired device; no SideStore-style source hosting exists in this design.
- **Running any anisette server**, self-hosted or otherwise.

## Constraints

- Refresh only succeeds while the iPhone is on the same physical Wi-Fi network as `mac-mini-m4-pro`. More
  than 7 consecutive days away from that network lets the signing certificate lapse; the app stops
  launching until the phone returns and AltServer re-signs it.
- Free Personal Team: up to 10 new App IDs per rolling 7 days. Re-signing an already-registered App ID
  (routine refresh) does not consume this quota — only creating a new one does.
- **At most 3 apps active at once with a non-developer Apple ID** ("You cannot activate more than 3 apps
  with a non-developer Apple ID.", confirmed directly in the AltServer binary's strings — this is an
  AltServer/Apple-side limit, not a SideStore-specific one). Forking many OSS repos means picking which 3
  stay installed at a time; deactivate one in AltServer before activating another.
- Forked OSS apps frequently need their bundle identifier changed before they'll sign under this Apple ID,
  since the original bundle ID is usually already claimed by the upstream App Store listing. This is
  handled per fork, not automated by `build-and-sign.sh`.
- AltServer's Apple ID sign-in flow has a 2FA verification-code callback. The one-time GUI login may
  prompt for a 2FA code interactively; `build-and-sign.sh` assumes that login already succeeded and the
  session is still valid, since it runs the same GUI binary non-interactively via `--udid`.

## Rejected Alternatives

- **SideStore + self-hosted anisette server**: forces exposing the anisette server beyond the Tailscale
  boundary (see "Why AltServer, Not SideStore" above).
- **SideStore + community anisette server**: avoids self-hosting/exposure, but reintroduces external
  dependency and shared machine-identity account-lock risk that self-hosting was meant to avoid.
- **Tailscale Funnel for the anisette/IPA endpoints**: solves the exposure/VPN-conflict problem but makes
  those endpoints reachable by anyone on the public internet, which was explicitly rejected.
- **Paid Apple Developer Program ($99/yr)**: would remove the 7-day/same-Wi-Fi constraint entirely (1-year
  certs, OTA install via `itms-services`), but conflicts with the "free" requirement. Left as a future
  option if the constraint becomes too limiting.
- **nix-casks / brew-nix-alternative Cask-to-derivation converters**: see "Why brew-nix" above.
