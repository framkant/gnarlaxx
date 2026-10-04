# 0003 — Preparing the public repository

Date: 2026-10-04

## Context and decisions

During asset preparation, the user provided the public GitHub destination,
`https://github.com/framkant/gnarlaxx.git`, and asked for a permissive license,
a README, and a numbered development journal.

Selected the MIT License for original project code, documentation, and original
asset additions. Third-party files retain their CC0 or public-domain terms;
the root README points to their credits and license notices.

## Changes

- Added `LICENSE` with copyright attributed to Gnarlaxx contributors.
- Added a root README explaining the learning goal, current asset-only state,
  local preview instructions, planned implementation order, and license scope.
- Added a small `.gitignore` for local build, Python, and macOS artifacts.
- Started this journal with retrospective planning and asset entries, plus an
  index and filename convention: `NNNN_short_description_YYYYMMDD.md`.
- Used the actual work date, 2026-10-04, for the filenames; the user's sample
  illustrated the numbering and naming pattern.

## Publication checkpoint

The configured publication destination is the user's repository above. Publish
with a normal push, preserving the existing planning history. The first public
checkpoint should contain the license, README, source credits, prepared assets,
and journal together. No game implementation is claimed at this stage.

Next is M0's minimal C/Sokol application and audio integration.
