---
name: bws
description: Use secrets from Bitwarden Secrets Manager via the bws CLI without exposing their values in the conversation. Use when a command needs an API key, token, or other runtime secret, or when the user mentions bws, Bitwarden Secrets Manager, or a machine account.
---

# bws (Bitwarden Secrets Manager)

Secrets reach a command as environment variables of a child process started by `bws run`.
Their values must never enter the conversation: transcripts persist on disk and are sent to the model provider.

Always go through `scripts/bws-agent` in this skill's directory (for Claude Code, `~/.claude/skills/bws/scripts/bws-agent`).
It fetches the machine-account token from rbw on every call, refuses subcommands that print values, and redacts secret values from command output.
Never call `bws` or `rbw get` directly.

## Trust model

- The agent authenticates as a **machine account** whose token is stored in rbw as `bws-agent-token`.
  The machine account can read only the projects the user granted it, and the agent may use anything in those projects freely.
  The boundary is what the user puts in those projects.
- The token has an expiry set by the user; when it expires, access ends.
- Never place a secret in an agent-readable project if it unlocks other secret stores (sops/age keys, SSH or GPG private keys, password manager master passwords).
  If you notice one there, stop and tell the user.

## Usage

`bws-agent` below stands for the full script path; it is not on `PATH`.

```bash
bws-agent project list                      # project names and IDs
bws-agent keys <project-id>                 # key names only
bws-agent run <project-id> -- '<command>'   # secrets injected as $KEY
```

- `run` passes the command to `sh -c`; reference secrets as `$KEY`, never interpolate a value yourself.
- Stdout and stderr of `run` are merged and every project value is replaced with `[REDACTED]`.
  This catches literal values only: a value split across lines or transformed (base64, hex, substrings) still leaks, so never print or transform a secret on purpose.
- The token is not passed to the child process.

If `bws-agent` fails with "is rbw unlocked?", stop and use the `ask-me-to-do` skill: ask the user to run `rbw unlock`.
Do not try to unlock rbw yourself.

## Changing bws-agent

After editing `scripts/bws-agent`, run `scripts/bws-agent.test.sh <project-name>`.
It talks to the real rbw and Secrets Manager; its header lists the dummy fixtures the project must hold.

## Never

- Bypass `bws-agent`: no `bws secret get`, `bws secret list` without filtering, or `rbw get` of the token.
- Write a secret to a file, commit it, or pass it as a command-line argument (arguments are visible in `ps`).
- Use verbose or debug flags on tools that log their environment or decrypted data.

## If a value leaks into the conversation

Tell the user immediately: which key, and that it is now in the transcript.
The secret must be rotated.
If the access token itself leaked, the user must revoke it in the web vault.
A machine that already authenticated keeps access for up to one hour after revocation, so rotate the affected secrets as well.
