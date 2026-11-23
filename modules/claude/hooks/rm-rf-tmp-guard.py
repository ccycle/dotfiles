#!/usr/bin/env python3
import glob
import json
import os
import re
import shlex
import sys

SHELL_METACHARACTERS = re.compile(r"[;&|<>$`(){}\n\\]")
TMP_ROOTS = ["/tmp", "/private/tmp", "/var/folders", "/private/var/folders"]


def tmp_roots():
    roots = TMP_ROOTS + ([os.environ["TMPDIR"]] if os.environ.get("TMPDIR") else [])
    return {os.path.realpath(r) for r in roots}


def strictly_inside_tmp(path):
    real = os.path.realpath(path)
    return any(real.startswith(root + os.sep) for root in tmp_roots())


def targets_all_in_tmp(command, cwd):
    if SHELL_METACHARACTERS.search(command):
        return False
    tokens = shlex.split(command)
    targets = [t for t in tokens[1:] if not t.startswith("-")]
    if not targets or any(".." in t.split("/") for t in targets):
        return False
    paths = [os.path.join(cwd, os.path.expanduser(t)) for t in targets]
    expanded = [m for p in paths for m in (glob.glob(p) if glob.has_magic(p) else [p])]
    return bool(expanded) and all(strictly_inside_tmp(p) for p in expanded)


def is_recursive_rm(command):
    try:
        tokens = shlex.split(command)
    except ValueError:
        return False
    return bool(tokens) and tokens[0] == "rm" and any(
        t.startswith("-") and not t.startswith("--") and ("r" in t or "R" in t) or t == "--recursive"
        for t in tokens[1:]
    )


def decide(command, cwd):
    if is_recursive_rm(command) and targets_all_in_tmp(command, cwd):
        return "allow", "every rm -r target resolves strictly inside a temporary directory"
    if re.search(r"\brm\s+-\S*[rR]", command):
        return "ask", "rm -r outside a temporary directory (or not a single plain command) needs confirmation"
    return None, None


def main():
    payload = json.load(sys.stdin)
    if payload.get("tool_name") != "Bash":
        return
    decision, reason = decide(payload.get("tool_input", {}).get("command", ""), payload.get("cwd", os.getcwd()))
    if decision:
        json.dump(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": decision,
                    "permissionDecisionReason": reason,
                }
            },
            sys.stdout,
        )


if __name__ == "__main__":
    main()
