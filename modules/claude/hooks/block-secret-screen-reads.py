#!/usr/bin/env python3
import json
import os
import shlex
import subprocess
import sys

SOPS_COMMANDS = {"sops", "sops-with-rbw"}
SOPS_ARGS_THAT_NEVER_SHOW_PLAINTEXT = {
    "set", "unset", "updatekeys", "filestatus", "encrypt", "-e", "--encrypt",
    "rotate", "-r", "--rotate", "--version", "-v", "--help", "-h", "help",
}
COMMAND_PREFIXES = {"env", "exec", "command", "sudo", "nice", "nohup", "time"}
SEPARATORS = {"|", "||", "&&", ";", "&", "(", ")", ";;", "|&"}
PANE_SCREEN_READS = {"read", "wait-output"}
ROTATE = ".agents/skills/credentials-manager/scripts/secret-rotate.sh"
RENDERED_SECRET_PATHS = ("nix-access-tokens.conf", "/run/secrets")
METADATA_ONLY_COMMANDS = {"ls", "stat", "test", "[", "readlink"}


def split(text):
    lexer = shlex.shlex(text, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        return list(lexer)
    except ValueError:
        return text.split()


def segments(text):
    for line in text.splitlines():
        segment = []
        for token in split(line):
            if token in SEPARATORS:
                yield segment
                segment = []
                continue
            segment.append(token)
            if any(c.isspace() for c in token):
                yield from segments(token)
        yield segment


def command_word(segment):
    for i, token in enumerate(segment):
        if token in COMMAND_PREFIXES or ("=" in token and not token.startswith("=")):
            continue
        return i
    return None


def shows_plaintext(segment):
    i = command_word(segment)
    if i is None or os.path.basename(segment[i]) not in SOPS_COMMANDS:
        return False
    return not SOPS_ARGS_THAT_NEVER_SHOW_PLAINTEXT.intersection(segment[i + 1:])


def reads_rendered_secret(segment):
    i = command_word(segment)
    if i is None or os.path.basename(segment[i]) in METADATA_ONLY_COMMANDS:
        return False
    return any(p in token for token in segment for p in RENDERED_SECRET_PATHS)


def shows_nix_access_tokens(segment):
    i = command_word(segment)
    if i is None or os.path.basename(segment[i]) != "nix":
        return False
    args = segment[i + 1:]
    if args[:1] == ["show-config"]:
        return True
    if args[:2] != ["config", "show"]:
        return False
    names = [a for a in args[2:] if not a.startswith("-")]
    return not names or "access-tokens" in names


def reads_pane_screen(segment):
    i = command_word(segment)
    return (
        i is not None
        and os.path.basename(segment[i]) == "herdr"
        and segment[i + 1:i + 2] == ["pane"]
        and bool(PANE_SCREEN_READS.intersection(segment[i + 2:i + 3]))
    )


def herdr(*args):
    out = subprocess.run(["herdr", *args], capture_output=True, text=True, timeout=10, check=True)
    return json.loads(out.stdout)["result"]


def panes_running_sops():
    found = []
    for pane in herdr("pane", "list")["panes"]:
        info = herdr("pane", "process-info", "--pane", pane["pane_id"])["process_info"]
        if any(os.path.basename(p["argv0"]) == "sops" for p in info.get("foreground_processes", [])):
            found.append(pane["pane_id"])
    return found


def block(reason):
    print(reason, file=sys.stderr)
    sys.exit(2)


def main():
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return
    command = payload.get("tool_input", {}).get("command", "")
    found = list(segments(command))

    for segment in found:
        if shows_plaintext(segment):
            block(
                f"Blocked: `{shlex.join(segment)}` decrypts secrets to a screen or to output the agent can read. "
                f"To replace one key, run `{ROTATE} --key <name> --from-bws <project-id> <bws-key> <file>`, "
                f"or pre-type `{ROTATE} --key <name> --from-prompt <file>` for the user. "
                "To list key names, run `yq 'keys' <file>` on the encrypted file. "
                "Whole-file `sops edit` is for the user's own terminal only."
            )

    for segment in found:
        if reads_rendered_secret(segment) or shows_nix_access_tokens(segment):
            block(
                f"Blocked: `{shlex.join(segment)}` can print a rendered sops secret such as the Nix GitHub/GitLab access tokens. "
                "Check presence with `test -s <path>` or `ls -l <path>`, "
                "or read one setting with `nix config show <name>` for a name other than access-tokens."
            )

    if any(reads_pane_screen(s) for s in found):
        try:
            busy = panes_running_sops()
        except (OSError, subprocess.SubprocessError, ValueError, KeyError) as e:
            block(f"Blocked: could not confirm that no Herdr pane is running sops ({e}); not reading a pane screen.")
        if busy:
            block(
                f"Blocked: Herdr pane(s) {', '.join(busy)} are running sops, so a screen may show decrypted secrets. "
                "Check the outcome with `git status` / `git diff --stat <file>` instead of reading the pane."
            )


main()
