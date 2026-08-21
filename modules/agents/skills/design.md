# Agent Skills Linking Design

## Purpose

Expose every skill in this directory to agent tools that read skills from
fixed locations under `$HOME` (Claude Code, Pi), while keeping each skill's
canonical source in this git checkout so it stays editable in place.

## Why This Structure

One symlink per skill, rather than a single symlink for the whole target
directory, so a sibling repo can add its own skills into the same target
directory without fighting for ownership of it.

## Rejected Alternatives

A single directory-wide out-of-store symlink (`~/.claude/skills` pointing
straight at this checkout) was tried and abandoned. It creates a failure mode
that is invisible until it silently defeats every future update:

Home Manager's own collision check compares each new per-skill symlink's
*target* against whatever already sits at the corresponding path under
`$HOME`. If the whole `~/.claude/skills` directory is itself a leftover
symlink into this checkout, then every per-skill path under it already
resolves — via that stale outer symlink — to the exact same file the new
generation would link to. The comparison sees identical content and skips
the update as a no-op. This isn't a one-time skip: the stale outer symlink
is never replaced, so every subsequent activation repeats the same false
"no-op" verdict indefinitely. Worse, any tool that treats
`~/.claude/skills/<name>` as its own private, writable copy (e.g. an
installer doing a backup-then-replace on skill files) ends up mutating the
live checkout through that stale link without knowing it.

The guard activation script does not try to distinguish a legitimately
stale symlink from a malicious or unexpected one — it only enforces the
invariant this design depends on: the two target directories must be real
directories, never symlinks themselves, so that per-skill entries inside
them are the only symlinks Home Manager ever needs to reconcile.

## Constraints

The guard must run before Home Manager's own link-collision check, or the
same masking failure mode reappears — a later fix has no effect once the
check has already concluded "nothing changed."
