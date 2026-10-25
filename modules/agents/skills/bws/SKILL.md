---
name: bws
description: Use secrets from Bitwarden Secrets Manager via the bws CLI without exposing their values in the conversation. Use when a command needs an API key, token, or other runtime secret, or when the user mentions bws, Bitwarden Secrets Manager, or a machine account.
---

# bws (Bitwarden Secrets Manager)

Secrets reach a command as environment variables of a child process started by `bws run`.
Their values must never enter the conversation: transcripts persist on disk and are sent to the model provider.

## Trust model

- The agent authenticates as a **machine account** through `BWS_ACCESS_TOKEN`.
  The machine account can read only the projects the user granted it, so everything in those projects is readable by the agent.
  The real boundary is what the user puts in those projects, not anything this skill does.
- The access token is issued with an expiry by the user.
  When it expires, access ends; there is no idle timer to keep alive.
- Never place a secret in an agent-readable project if it unlocks other secret stores (sops/age keys, SSH or GPG private keys, password manager master passwords).
  If you notice one there, stop and tell the user.

## 1. Check the token is present

```bash
test -n "${BWS_ACCESS_TOKEN:-}" && echo set || echo missing
```

If it is missing, stop and use the `ask-me-to-do` skill.
Ask the user to export `BWS_ACCESS_TOKEN` in the shell that launches the agent, then restart the agent.
Never fetch the token yourself from a password manager (`rbw`, `bw`, Keychain), and never ask the user to paste it into the chat.

## 2. Find the project

```bash
bws project list --output table
```

This lists project names and IDs only.
If several projects are listed and the task does not say which one to use, ask the user.

## 3. Run the command with secrets injected

```bash
bws run --project-id <PROJECT_ID> -- '<command>'
```

- Each secret becomes an environment variable named after its key.
- The command is passed as a single string and run by `sh`.
  Reference secrets as `$KEY` inside the command; never interpolate a value into the string yourself.
- Add `--no-inherit-env` when the command does not need your environment.
  Only `PATH` is kept, so commands that need `HOME` or similar may break.
- Prefer passing the secret to a fixed script or tool that consumes it, rather than an ad-hoc pipeline.

## Never

- Print a secret or the token: no `echo $KEY`, `env`, `printenv`, `set -x`, or verbose/debug flags on tools that log their environment or decrypted data.
- Run `bws secret get` or `bws secret list` unless the user explicitly asks; both return secret **values** in their JSON output.
  To learn key names, ask the user.
- Write a secret to a file, commit it, or pass it as a command-line argument (arguments are visible in `ps`).

## If a value leaks into the conversation

Tell the user immediately: which key, and that it is now in the transcript.
The secret must be rotated.
If the access token itself leaked, the user must revoke it in the web vault.
A machine that already authenticated keeps access for up to one hour after revocation, so rotate the affected secrets as well.
