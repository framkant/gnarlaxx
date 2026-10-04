# 0005 — First playable C reference

Date: 2026-10-04

## Scope and implementation

Built the complete single-level C game on the native foundation from `6526bf9`:

- Main menu, high-score display, minimal volume controls, briefing text and
  voice, black fade, player entry, and results/replay flow.
- Acceleration/drag, banking poses, held fire, three lives, and short respawn
  invulnerability. Escape pauses; focus loss also pauses and clears held keys.
- Ten five-pawn formations, five warning/charging drones, and a multipart boss.
  The boss roams, warns, fires arcs, retracts its guns, rams, and returns. Its
  two ten-hit gun holders protect the ten-hit core, which fires faster once open.
- Score events and a local top-five list, written through a temporary file and
  rename. Missing or malformed files become an empty list.
- Music, one-shot effects, briefing voices, and master/music/effect levels.
  Long warning/engine recordings are limited to short one-shots with a fade-out.

The simulation runs at a fixed 120 Hz. It keeps enemies, bullets, and explosions
in bounded arrays. Rendering reads the state; sound and completed-run events
are consumed by `main.c`. The gameplay module has no window or graphics API
dependency, allowing direct deterministic checks of the same code used in play.

Added a format configuration and formatted the original C code for readability.
Detailed walkthroughs remain deferred; this entry records what was built and
why the main pieces were separated.

## Validation

The C test executable passed in Debug, Release, and a build with AddressSanitizer
and UndefinedBehaviorSanitizer. Checks cover movement/drag, held fire, menu and
briefing transitions, pause/resume, volume limits, all scheduled enemies, all
seven boss states, three-life loss, protected core, exact ten-hit components,
victory and replay, score persistence/corruption/write failures, eight concurrent
effects, resampling, mixer pause/mute, and music wraparound.

One subtle collision detail was handled explicitly: after the core opens, shots
must pass through the lower central hull to reach the recessed core. A test
fires a moving bullet from below the boss and verifies that it reaches the core.

Native runs verified the menu, regular combat, boss gun destruction, and the
exposed-core presentation. Captures in `docs/images/` come from the actual Metal
render target. A native core-scene run also completed under the sanitizers
without reported address/undefined-behavior errors.

The full native diagnostic run reached victory with score 9,600 at mission time
52.75 seconds. This used an **invulnerable automated pilot**. It verifies the
integrated flow and completion path, not human difficulty or control feel. The
user observed the run and said it looked quite okay; a normal playthrough and
any resulting tuning remain the next feedback step.

## Rough measurements

macOS arm64, Apple Clang 17, CMake Release configuration, Metal, Sokol output at
44.1 kHz. This is one local observation rather than a controlled benchmark.

| Measurement | Observed value |
| --- | --- |
| Release executable size | 481,016 bytes |
| Game-state structure | 14,500 bytes |
| Decoded audio samples | 31.15 MiB |
| Full-run window lifetime | 4,574 frames over 76.45 seconds |
| Average presentation rate | 59.8 FPS |
| Total process CPU time | 4.783 seconds |
| Peak resident memory | 90.80 MiB |
| Frame-callback wall time, average / maximum | 11.724 ms / 47.501 ms |

The window closed after victory and before the requested 12,000-frame capture
limit. The measurements include the briefing and time on the results/menu flow.
Process CPU time includes startup; the reported wall interval starts after
initialization. Frame-callback time includes graphics/presentation waits and is
not a pure simulation cost or GPU measurement. A later short regular-combat
capture averaged 1.390 ms per callback at the same roughly 60 FPS, illustrating
why these numbers should not yet be treated as a language benchmark.

Predecoding all audio is the largest explicit CPU-memory allocation. It keeps
loading, mixing, and looping straightforward for this small project. No
performance-driven redesign is justified yet.

## Next

The first playable C version is ready for user playtesting. M0 is complete;
M1's feedback/tuning step remains. Keep this version as the behavioral reference
once satisfactory, then proceed to Odin and Zig. A real playthrough should judge
difficulty, drift, readability, audio balance, and perceived music-loop continuity.
