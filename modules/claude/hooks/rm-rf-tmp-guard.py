#!/usr/bin/env python3
import json
import os
import re
import shlex
import sys

OPTION = r"(?:-[rRfvd]+|--recursive|--force|--verbose)"
LITERAL = r"[A-Za-z0-9_./,:@%+=*?-]"
TARGET = rf"(?:/{LITERAL}*|'/(?:{LITERAL}| )*'|\"/(?:{LITERAL}| )*\")"
SINGLE_PLAIN_RM = re.compile(rf"rm(?: +{OPTION})*(?: +--)?((?: +{TARGET})+) *")
RECURSIVE_RM_ANYWHERE = re.compile(r"\brm\s+-\S*[rR]")
GLOB = re.compile(r"[*?]")
INSIDE_TMP = re.compile(
    rf"(?:{re.escape(os.path.realpath('/tmp'))}|/private/var/folders/[^/]+/[^/]+/T)/.+"
)


def strictly_inside_tmp(target):
    if {".", ".."}.intersection(target.split("/")):
        return False
    parent, name = os.path.split(target)
    if GLOB.search(parent):
        return False
    real_parent = os.path.realpath(parent)
    if GLOB.search(name):
        return "**" not in name and bool(INSIDE_TMP.fullmatch(real_parent))
    follows_final_symlink = name == ""
    removed = real_parent if follows_final_symlink else os.path.join(real_parent, name)
    return bool(INSIDE_TMP.fullmatch(removed))


def removes_only_tmp(command):
    plain = SINGLE_PLAIN_RM.fullmatch(command)
    return bool(plain) and all(strictly_inside_tmp(t) for t in shlex.split(plain.group(1)))


def decide(command):
    if removes_only_tmp(command):
        return "allow", "every rm target is a literal path strictly inside a temporary directory"
    if RECURSIVE_RM_ANYWHERE.search(command):
        return "ask", "rm -r outside a temporary directory (or not a single plain command) needs confirmation"
    return None, None


def main():
    payload = json.load(sys.stdin)
    if payload["tool_name"] != "Bash":
        return
    decision, reason = decide(payload["tool_input"]["command"])
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
