---
name: prototype
description: Build a throwaway prototype outside the repository to settle a design or behavioral question cheaply — which layout, which approach, how a tool actually behaves — then recommend from what was observed. Use when a choice could be settled by an experiment instead of a guess or a question, or for /prototype.
---

# Prototype

The prototype is an instrument for a decision, not code to ship.
Speed beats polish.

## Exemptions

A prototype built outside the repository (in the session scratchpad or another temporary directory) is exempt from the completion criteria protocol, the no-comments rule, and verify-change.
The exemption ends the moment code moves into the repository: the real build then follows the normal rules.

## Steps

1. Write down the one question the prototype exists to answer, and what observation would answer it.
   No question means no prototype.
2. Build in a fresh scratch directory, separate from the repository.
   Use the lightest stack that exercises the question: a shell or Python script for behavior or timing, plain HTML for a visual layout, a throwaway flake for a Nix evaluation question.
3. When comparing alternatives, build each variant and label it, ideally behind one switch so they can be compared side by side.
   Propose a variant the user did not ask for when the design space is open.
4. Observe the thing being decided: print the output, time it, screenshot it.
   The observation is the test.
5. Recommend one option from what was observed.
   Leave product or preference choices that no observation settles to the user.

## Report

The question, the variants, the observed evidence for each, the recommendation, and the scratch path, stated plainly as throwaway.

## Sources

Adapted (rewritten, not copied) from the `prototype` playbook in [cursor/plugins pstack](https://github.com/cursor/plugins/tree/main/pstack) (MIT).
