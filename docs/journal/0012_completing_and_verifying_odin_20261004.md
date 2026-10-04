# 0012 — Completing and verifying Odin

The simulation checkpoint was committed as `55a022d`. The port now includes
its own application loop, input handling, renderer, presentation and persistent
scores, alongside the shared audio library. The same assets, controls, mission
rules and diagnostic options are available. It is ready for user playtesting;
Zig has not started.

## Boundaries and choices

Sokol bindings use the pinned C implementation already in the repository. A
second archive builds the same platform glue with `SOKOL_NO_ENTRY`, allowing Odin
to supply `main`. PNG decoding and audio remain C dependencies, but no C gameplay,
renderer, presentation or score implementation is linked into the Odin game.

Odin's dynamic arrays carry their allocator and replace C's repeated typed growth
functions. A small generic `push` records append failures; stable generic
compaction preserves survivor order. Restart clears lengths and retains storage.
Events are a union of sound and finished-run payloads, consumed with a type switch.
Enum-indexed arrays hold menu labels, sound descriptors and volume settings.

Persistent game allocations use `context.allocator`. Frame text, formatted paths
and C strings borrow `context.temp_allocator`, which is reset after startup and
frames. Native callbacks explicitly restore Odin's context. No element pointers
are retained across collection growth, and copying a live owning `Game` is still
a programmer error: the language does not remove that responsibility.

Native shutdown testing exposed an important lifetime boundary: macOS Sokol can
terminate the process without returning from `sapp.run`. Cleanup of the owned
score path and the debug allocation tracker therefore happens in the Sokol
cleanup callback, along with game, audio and graphics teardown. Relying only on
`defer` in `main` would miss that path.

## Build friction

The installed Odin is `dev-2025-03:951bef4ad`, built against LLVM 19.1.7. Its
Homebrew library path currently resolves to LLVM 20.1.5. Debug/default optimization
worked, but `-o:speed` failed with an invalid `use-loop-info` pass parameter.

The matching LLVM 19.1.7 and Z3 4.14.1 libraries were already installed. Running
the compiler binary directly with a process-local library path fixes optimized
builds; no system packages, symlinks or shell configuration were changed.
`tools/build_odin.py` accepts compiler/library-path overrides, and the exact
working command is in the Odin README. The built game needs no override.

The selected compiler also requires copying a constant sprite table into an
addressable value before runtime indexing. The generated `sprite_rect` helper
contains that detail; rectangle dimensions still come from the common manifest.

## Verification

Eight tests cover the following in debug and optimized builds:

- Movement, drag, bounds, firing, intro voice timing, menus, volume bounds,
  pause/resume, three lives and loss; boss gun/core damage and all boss phases.
- Three complete headless missions/replays, each ending at 9,600 points and
  52.75 seconds with all ten waves and five drones accounted for.
- Two thousand entries in each dynamic collection, forced relocation on every
  growth, stable compaction, capacity reuse, and all 32 allocation failure
  positions. Terminal failure stops further updates; destruction leaves no
  tracked allocations, including after partial initialization and repeated free.
- The shared score format, malformed input, insertion order, save/load, replacement
  and failed writes. Both versions use `GNARLAXX 1` plus five descending scores.
- Calling the actual C audio library from Odin: decoding, nonzero finite samples,
  pause, mute, voice limits, stop and destruction. The descriptor's C layout is
  checked at compile time. Native output initializes at 44.1 kHz.
- Held movement/fire versus one-shot input, key-repeat suppression, release,
  focus-loss pause and the diagnostic autopilot's focus exception.

A native optimized run with audio completed the full mission and captured victory
at frame 3,700. Menu, exposed-core and victory render-target captures were inspected.
A debug exposed-core run reached victory and reported zero live Odin allocations
at shutdown, including the owned default score path. Sokol validation was enabled.
Diagnostic runs do not save scores. The existing three C test suites still pass.

## Lightweight observations

On this Apple M3 Max/macOS build, Odin's `Game` occupies 376 inline bytes and the
full diagnostic mission retains 3,200 collection bytes: capacities of eight
enemies, 120 bullets, eight explosions and eight events. C's corresponding
figures were 280 inline plus 1,920 retained bytes, with 64 bullets. Odin's default
growth policy and wider `int` fields contribute; no attempt was made to tune
capacity or pack types merely to improve the comparison. Allocator overhead and
shared library resources are excluded from these collection figures.

The native run reported 3,700 frames in 61.81 seconds (59.9 FPS), average frame work
10.739 ms and maximum 48.122 ms. `/usr/bin/time -l` reported 2.27 seconds user plus
2.24 seconds system CPU and 97,353,728 bytes (92.84 MiB) maximum resident set size.
Shared decoded audio remains 31.15 MiB. Frame work includes presentation waiting;
these desktop measurements are rough observations, not controlled evidence of a
language performance advantage. Ignored logs/captures live under `build/odin`.

The complete walkthrough and comparison remain M4, after the Zig implementation.
