#!/usr/bin/env python3
import json
import os
import re
import shlex
import sys

OPTION = r"(?:-[rRfvd]+|--recursive|--force|--verbose)"
LITERAL = r"[A-Za-z0-9_./,:@%+=*?-]"
TARGET = rf"(?:/{LITERAL}*|[A-Za-z0-9_]{LITERAL}*|'/(?:{LITERAL}| )*'|\"/(?:{LITERAL}| )*\")"
SINGLE_PLAIN_RM = re.compile(rf"rm(?: +{OPTION})*(?: +--)?((?: +{TARGET})+) *")
RECURSIVE_RM_ANYWHERE = re.compile(r"\brm\s+-\S*[rR]")
GLOB = re.compile(r"[*?]")
INSIDE_TMP = re.compile(
    rf"(?:{re.escape(os.path.realpath('/tmp'))}|/private/var/folders/[^/]+/[^/]+/T)/.+"
)
HERDR_WORKTREES = os.path.realpath(os.path.join(os.environ["HOME"], ".herdr", "worktrees"))


def real_removal_root(target, cwd):
    if {".", ".."}.intersection(target.split("/")):
        return None
    parent, name = os.path.split(os.path.join(cwd, target))
    if GLOB.search(parent) or "**" in name:
        return None
    real_parent = os.path.realpath(parent)
    removes_children_or_follows_symlink = name == "" or GLOB.search(name)
    return real_parent if removes_children_or_follows_symlink else os.path.join(real_parent, name)


def herdr_worktree_of(cwd):
    rel = os.path.relpath(os.path.realpath(cwd), HERDR_WORKTREES).split("/")
    if rel[0] in ("..", ".") or len(rel) < 2:
        return None
    root = os.path.join(HERDR_WORKTREES, rel[0], rel[1])
    return root if os.path.isfile(os.path.join(root, ".git")) else None


def strictly_inside_tmp(target, cwd):
    removed = real_removal_root(target, cwd)
    return target.startswith("/") and removed is not None and bool(INSIDE_TMP.fullmatch(removed))


def strictly_inside_worktree(target, cwd):
    root = herdr_worktree_of(cwd)
    removed = real_removal_root(target, cwd)
    if root is None or removed is None or not removed.startswith(root + "/"):
        return False
    return ".git" not in removed[len(root) + 1:].split("/")


def removes_only_disposable(command, cwd):
    plain = SINGLE_PLAIN_RM.fullmatch(command)
    return bool(plain) and all(
        strictly_inside_tmp(t, cwd) or strictly_inside_worktree(t, cwd)
        for t in shlex.split(plain.group(1))
    )


def decide(command, cwd):
    if removes_only_disposable(command, cwd):
        return "allow", "every rm target is a literal path strictly inside a temporary directory or the current herdr worktree (outside .git)"
    if RECURSIVE_RM_ANYWHERE.search(command):
        return "ask", "rm -r outside a temporary directory or the current herdr worktree (or not a single plain command) needs confirmation"
    return None, None


def main():
    payload = json.load(sys.stdin)
    if payload["tool_name"] != "Bash":
        return
    decision, reason = decide(payload["tool_input"]["command"], payload["cwd"])
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
