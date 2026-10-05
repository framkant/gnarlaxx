# 0014 — Completing and verifying Zig

The simulation/bindings checkpoint was committed as `5c2070f`. Zig now implements
the complete native game and is ready for user playtesting. The dynamic C version
remains the behavioral baseline; the fixed-array `c-original-reference` tag was
not changed. Odin's playtest was accepted in the user's request to start Zig.

## Implementation and boundaries

The root `build.zig` defines the application and tests. `tools/build_zig.py` is a
small convenience wrapper for the pinned compiler, build profiles and ignored
cache/output paths. It chooses Zig 0.17.0 from PATH or the verified project-local
copy, with `--zig` available for an explicit path. Dependencies are vendored;
the build itself performs no downloads. Optimized builds use Zig 0.17's `safe`
mode, retaining runtime safety checks. Debug builds enable Sokol validation.

Zig compiles its own gameplay, renderer commands, UI, input and score handling.
CMake builds the same PNG decoder, shared audio library and native Sokol glue as
Odin. The existing archive name `libsokol_odin.a` refers only to platform glue
compiled with `SOKOL_NO_ENTRY`; there is no Odin code in it. The audio header is
translated by Zig's build and imported as a module, rather than duplicating the
C ABI declarations by hand. Six official Sokol binding modules remain unmodified.

Game data uses `std.ArrayList` with an allocator stored by the owning `Game`.
Growing operations propagate errors with `try`. Start/update use `errdefer` to
mark allocation failure terminal; there is no rollback of a partly applied step.
The app discards that step's events and shuts down. Clearing lengths on replay
retains capacity, stable compaction preserves survivor order, and `deinit` frees
all four collections. Element-pointer validity and avoiding copies of owning
state remain explicit responsibilities.

Sound and finished-run events are a tagged union. Fixed rules such as volume
channels and menu choices use enums and `EnumArray`. UI number formatting uses
stack buffers, while audio startup uses a temporary arena for borrowed C paths.
Score persistence takes `std.Io` and allocator parameters explicitly and uses
temporary-file/rename replacement with the common on-disk format.

Resource teardown lives in the Sokol cleanup callback, applying the lifetime
lesson from Odin: Cocoa can terminate without returning from `sapp.run`. The
application's own debug allocator is finalized there, including the owned score
path. Zig's process-startup arena and native library allocations are separate
from that application allocator.

## Verification and corrections

Both debug and optimized builds pass all ten Zig test-runner entries (nine
behavioral tests plus the test-discovery entry):

- Three complete missions/replays, each with score 9,600, mission time 52.75
  seconds, three remaining lives, ten waves, five drones and one finished event.
- Movement, acceleration/drag, bounds, firing, intro voice timing, menus,
  pause/resume, volume bounds, replay, boss collisions/scoring, all seven boss
  phases, and losing all three lives.
- Collection growth to 2,000 elements, forced allocation/copy/free on every
  growth, stable compaction and capacity reuse. The stress sequence makes 52
  allocations. `std.testing.checkAllAllocationFailures` injects failure at every
  position and verifies no leaks or swallowed errors. Separate checks exercise
  terminal errors inside start/update and destruction after partial work.
- The common score format, ordering, malformed input, save/load, replacement and
  failed writes. Zig's integer parser permits underscore separators, so the file
  parser explicitly rejects them to preserve the shared decimal format.
- Calls into the actual shared audio library: decode, finite nonzero samples,
  mute, pause, stop, voice limits and destruction. Native output opens at 44.1 kHz.
- Held keys versus pressed edges, key-repeat suppression, release, focus-loss
  pause and the diagnostic autopilot exception.

The native optimized autopilot completed the full mission with audio through
victory at frame 3,700. Menu, exposed-core and victory captures were inspected.
The first victory capture exposed a formatting difference: padded signed Zig
integers include a positive `+`. Rendering the nonnegative score as an unsigned
value corrects the HUD, results and high-score list. A follow-up native result
capture checks the corrected formatting; gameplay was unaffected.

A debug native exposed-core run reached victory and reported allocator status
`ok` after shutdown. An intentionally missing asset directory exercised startup
failure after graphics setup: it exited with status 1, reported the failed PNG
load and again finalized the application allocator with status `ok`. Diagnostic
runs did not create a score file. All three existing C suites still pass, vendor
checksums match, and generated Zig geometry is reproducible byte for byte.

## Rough observations

On this Apple M3 Max/macOS build, `Game` occupies 288 inline bytes. A complete
mission retains 2,552 collection bytes: capacities of ten enemies, 94 bullets,
seven explosions and eleven events. C previously retained 1,920 bytes and Odin
3,200. These figures reflect the chosen field representations and each list's
capacity policy, exclude allocator overhead, and are not process-memory totals.
We did not tune reserve sizes to manufacture a favorable comparison.

The native `safe` build reported 3,700 frames in 61.67 seconds (60.0 FPS), average
frame work of 0.319 ms and a maximum of 3.725 ms. `/usr/bin/time -l` recorded 2.33
seconds user plus 2.09 seconds system CPU, and 96,632,832 bytes (92.16 MiB) maximum
resident set size. Shared decoded audio remains 31.15 MiB. Logs and render-target
captures are ignored under `build/zig`.

These are separate desktop runs, not a controlled benchmark. Presentation waiting
and scheduling can affect frame callback timings, and the implementations use
different optimizations, allocation policies and temporary formatting approaches.
A language ranking would require more controlled evidence.

M3 implementation and verification are complete, awaiting the user's playtest.
M4 walkthroughs and the language comparison remain the next milestone.
