# LM Studio Design

## Purpose

Install LM Studio as a GUI application for interactive model
exploration and testing. LM Studio is not used for serving — that role
has moved to `modules/llm-server` (llama-swap + llama-cpp).

## Why Keep the Cask

LM Studio provides a convenient GUI for trying new models, adjusting
parameters interactively, and comparing outputs. It complements the
declarative llm-server by serving as a playground that doesn't affect
the production serving pipeline.

## Constraints

- The DMG is APFS-based, requiring the 7zz workaround for Nix
  extraction (alternate data streams and chained symlinks).

## Rejected Alternatives

- **Removing LM Studio entirely** — the GUI remains useful for ad-hoc
  experimentation outside the declarative pipeline.
