---
name: blast-radius
description: Find what a change to this dotfiles repo could break outside its diff — other profiles, merged option values, activation, launchd services, deployed hosts — and prove the one fact it is safe because of by running nix, not by writing it up. Use for "blast radius of X", "what could this break", or before merging a small diff you do not fully trust.
---

# Blast Radius

Listing callers is not the job; `grep` does that in a second.
The job is the breakage `grep` cannot show.

A writeup that sounds right is worthless on its own, because it reads as convincing whether or not it is true.
So the deliverable is not the writeup but the proof of the one or two facts the change's safety rests on.

## Proof ladder

For each fact the change's safety depends on, push it as far down this ladder as is cheap, and say where it stopped.

1. Asserted. Worthless alone.
2. Pointed at. A real `file:line`, or the upstream module's source in the pinned nixpkgs / home-manager / nix-darwin.
3. Walked. The failure path traced step by step and shown not to reach.
4. Evaluated or built. A `nix eval` or `nix build` that fails loudly if the fact is wrong.
5. Observed. The switched system or the running service shows it (`darwin-rebuild` result, `launchctl print`, a smoke-test skill).

Level 4 is usually reachable and cheap: evaluate the option at the base revision and at the change, and compare.

## Steps

1. Read the change: the diff, every option it sets or declares, and what it now does differently, including what the diff does not spell out.
2. Find the one fact it is safe because of.
   Most changes that look risky are safe because of a single fact, such as "this option is only read inside `lib.mkIf cfg.enable` and no profile enables it".
   Spend the time here, not on a long list of maybes.
3. Look where `grep` stops.
   In this repo that usually means:
   - Option merging: `mkDefault` / `mkForce` / `mkOverride` priorities, list and attrset merging from several modules, and `mkIf` gates.
     The value that wins is only visible through evaluation.
   - Profiles: host modules toggle `enable` flags, so a shared-module change may matter in one profile only.
     Check every profile the change can reach.
     List them with `nix eval --json .#darwinConfigurations --apply builtins.attrNames`; a profile whose value is keyed by system (such as `bootstrap`) needs `.<system>` appended.
   - Activation: home-manager link collisions and `.backup` files, `home.activation` scripts, and launchd agents that restart when their plist changes.
   - Generated files read by something other than Nix: compose files, Caddyfiles, plists, JSON settings.
     Their consumer, not Nix, decides whether the new content is valid.
   - Deployment: comin deploys the committed flake, so a merge to the tracked branch is a deploy to every host that follows it.
4. Be honest about each risk: how it breaks, how likely, how costly.
   Keep confirmed risks; list checked-and-cleared ones separately.
   A search that finds nothing is still an answer; never invent a consumer or an option.
5. Prove the one fact by running it, and paste the output.
   Compare the change against its merge base:

   ```bash
   base=$(git merge-base HEAD main)
   attr='darwinConfigurations.<profile-path>.config.<option.path>'
   nix eval --json "git+file://$PWD?rev=$base#$attr"
   nix eval --json ".#$attr"
   ```

   For a wide change, compare whole closures for the affected profile instead:

   ```bash
   nix build --no-link --print-out-paths "git+file://$PWD?rev=$base#darwinConfigurations.<profile-path>.system"
   nix build --no-link --print-out-paths ".#darwinConfigurations.<profile-path>.system"
   nix store diff-closures <base-out> <head-out>
   ```

   `.#…` evaluates the working tree including uncommitted (but git-tracked) files; `?rev=` evaluates exactly that commit.

## Report

- What it does, including the non-obvious part.
- The one fact it is safe because of, the ladder level it reached, and the proof output — or `unproven`.
- Risks: mechanism, `file:line`, likelihood and cost, and how to check.
- Cleared: what was checked and why it is fine.
- Before merge: the cheapest check that would catch the real failure, including any command written for step 5.

## Sources

Adapted (rewritten, not copied) from the `blast-radius` skill in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT): the single-safety-fact framing and the proof ladder.
