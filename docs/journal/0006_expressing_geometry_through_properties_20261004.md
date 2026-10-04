# 0006 — Expressing geometry through properties

Date: 2026-10-04

After playing the C reference at `293496a`, Filip found the game fun and the code
straightforward, but pointed out unexplained numbers such as the drone spawn
position `{70 + 65 * (n % 5), -24}`. The request was to express the properties
behind those numbers while keeping the implementation simple.

## Changes and reasoning

Added `implementations/c/properties.h` for gameplay tuning and shared geometry.
Formation spacing is now `(GAME_WIDTH - 2 * side_margin) / (count - 1)`, with a
single ship centered. The drone's 65-pixel spacing follows from the 400-pixel
playfield, two 70-pixel center margins, and five lanes. Its entry height follows
from half the sprite height plus an eight-pixel gap above the screen. Pawn
formations use the same calculation and derive their middle slot from the count.

Side margins, speeds, collision circles, and delays remain authored tuning choices.
Naming them makes their purpose visible; they are not all consequences of some
deeper measurement. Derived positions and dimensions now use those choices:

- Player bounds account for the HUD, ship dimensions, and exhaust height. Entry
  movement uses its start and destination instead of a separate travel distance.
- Boss gun/core centers use the manifest's existing part offsets and sprite
  rectangles. Drawing, hit tests, and muzzle positions share that geometry.
- Mission counters and health bars use the configured counts and hit points.
- Sprite centering, title centering, atlas/font coordinates, and background tile
  coverage use asset and playfield dimensions. Background pattern data also comes
  from the manifest.
- Drone warning/charge timing is shared between simulation and presentation.
  Explosion lifetime follows its frame count and animation rate. Menu and volume
  indexing use named entries and counts.

The asset generator now emits the additional geometry into the checked-in C
header. Everything is still compile-time data and ordinary functions; no runtime
configuration loader or new dependency was introduced. Cosmetic colors, effect
gains, and authored menu text positions remain local to their uses.

## Validation

- Release build and the existing simulation, persistence, and audio checks passed.
- AddressSanitizer/UndefinedBehaviorSanitizer build and checks passed.
- A temporary harness compared the old and new simulation at 120 Hz for three
  95-second runs: invulnerable observation through the boss cycle, firing autopilot
  through victory (9,600 points), and stationary vulnerable play through game over.
  Hashes of the recorded player/enemy/bullet/boss state and events matched exactly.
- A rendering stub recorded sprite, text, and rectangle calls for all eight scenes,
  with the boss core both closed and open. All sixteen command streams matched.
  This checks drawing inputs, not GPU output. The temporary comparison lives under
  ignored `build/property-check/`; it is not a new permanent test framework.

The C reference is still the only implementation. Odin and Zig, followed by the
walkthrough and language comparison, remain ahead.
