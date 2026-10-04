# 0001 — From rough plan to better plan

Date: 2026-10-04

This entry reconstructs the planning conversation when the journal was
introduced. The original rough plan is in commit `0ec4bd7`; the replacement
plan is in `6d92d9e`.

## Starting point

The repository contained a rough description of Gnarlaxx: a vertical shooter
with parallax graphics, sound, a short scripted level, and a boss. The broader
idea was to implement it in several languages and compare the results.

The user asked for follow-up questions and for the resulting decisions to
replace the original plan before implementation began.

## Decisions from the conversation

- The main interest is how a game is expressed, especially how graphics, audio,
  and gameplay interact. Language tradeoffs matter when we can identify them
  from the actual implementations. Performance is secondary.
- Compare C, Odin, and Zig. The first implementation may use another language
  if useful; the rewritten plan defaults to C first to avoid an extra prototype.
- Prefer Sokol because the user already uses it. Audio may require miniaudio.
  Prefer common libraries across versions while retaining idiomatic game code.
- Keep it a small learning exercise. One level is enough to demonstrate the
  major systems; extensibility and production polish are unnecessary.
- Keep the existing asset approach: download a suitable free/open sprite sheet
  first, then use generated art and scripts only if needed. Asking the user to
  repeat this preference was unnecessary; it was already in the rough plan.
- Use WASD with acceleration and drag, hold Space to fire, three lives, brief
  invulnerability after a hit, and no pickups.
- Add minimal pause/resume and high scores saved between sessions.
- Write the walkthroughs and language comparison after implementation, when
  there is real code to discuss.
- Commit to Git reasonably often, at coherent checkpoints.

## Result and checks

Replaced `plan.md` with the agreed scope, explicit milestones, and acceptance
criteria. Retained the original display resolution, audio requirements, ten
five-enemy waves, five drones, and the boss's separate ten-hit gun holders and
ten-hit exposed core. Checked the diff for whitespace issues and committed it.

At this checkpoint there was no game implementation or asset work. The next
instruction was to begin by solving the asset question.
