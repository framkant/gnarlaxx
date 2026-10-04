# 0010 — Dynamic C comparison baseline

Date: 2026-10-04

After verifying shared audio, committed and pushed `9ce2512` with the annotated
tag `c-original-reference`. That tag is the canonical C implementation of the
original task, including fixed game pools. This entry records the subsequent
dynamic variant requested in entry 0008. Odin and Zig will be compared against
this variant, using the same shared audio library.

## Collections and lifetime

Enemies, bullets, explosions, and outgoing events now use typed lists with data,
count, and capacity. They allocate on first use, start at eight elements, and
double when full. They have no fixed gameplay capacity. The player, single boss,
volume channels, and five-entry score table remain values with sizes fixed by the
game's rules.

The lists belong to `Game`. Each add copies its value and checks allocation.
Collisions/expiry mark entities inactive; stable compaction removes them after
the update. No collection is resized or compacted while one of its elements is
borrowed by a loop that can mutate that same collection. Surviving entities stay
in creation order, rather than the original pool's first-free-slot order.
Pointers and indices are temporary, not persistent entity identities.

Replay resets live lengths and gameplay values, preserving capacity and volumes.
The host consumes the event list and resets its length. `game_destroy` frees all
four buffers and clears state. Copying a live owning `Game` is forbidden by the
API contract; existing tests now initialize and destroy their state explicitly.

Growing storage uses a small realloc-style allocator hook, defaulting to the C
heap. Failed growth leaves the previous pointer, capacity, and contents intact.
The game records terminal allocation failure, and update/start/add operations
report failure. There is no rollback of an already partially applied step. The
app skips its events, reports the error, destroys resources, and exits with a
failure status. Tests use the hook to force both movement and failure.

The typed append and compaction functions are intentionally ordinary C. Their
repetition makes the manual work visible for the later language comparison;
there is no general collection framework or entity-component engine. This
extends the memory-management exercise while retaining the original one-level
game and its content.

## Verification

- Release and AddressSanitizer/UndefinedBehaviorSanitizer builds passed all
  three suites: existing gameplay/persistence, dynamic memory, and shared audio.
- The memory suite grew each entity collection to 1,100 elements and accumulated
  100 events, exceeding all four original limits. Values survived every forced
  move; removal preserved survivor order.
- A hundred resets preserved volumes and reused existing capacity. Destruction
  returned tracked live allocation bytes to zero, including repeated destruction.
- All 32 allocation failure points in the stress sequence were injected, plus
  the first allocation during `game_start`. Existing storage survived failure;
  terminal failure stopped subsequent updates and cleanup released ownership.
- Three headless autopilot missions, using an allocator that always moves on
  growth, each reached victory with three lives, score 9,600, mission time
  52.75 seconds, and exactly one finished event. The first run made seven growth
  allocations; later runs reused them.
- A native muted autopilot run completed the mission through victory and captured
  the result at frame 3,700. Metal and shared 44.1 kHz audio remained operational,
  and the app shut down normally. Capture: ignored `build/dynamic-check/victory.png`.

## Lightweight observations

On this macOS build, `Game` is now 280 inline bytes. The diagnostic mission retained
1,920 collection bytes: capacity for eight enemies, 64 bullets, eight explosions,
and eight events. The original tagged game's inline state was 14,500 bytes. These
figures exclude heap allocator overhead and the shared audio/rendering resources;
they are not process memory totals or evidence of a general language advantage.

The native run reported 3,700 frames over 62.84 seconds (58.9 FPS), 4.597 seconds
of process CPU, and 90.33 MiB peak RSS. Its frame callback had a roughly one-second
outlier, so this desktop run is not a controlled timing comparison. The shared
decoded audio remains 31.15 MiB.

## Next

M1a and M1b are complete. Odin is next, followed by Zig, with the dynamic C game
as the implementation baseline and the tagged original C game retained for
historical comparison. Each port should express collection ownership and failure
handling idiomatically while preserving gameplay and using the common audio API.
