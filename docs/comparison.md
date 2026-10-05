# C, Odin and Zig: what this game showed

All three implementations are playable and user-tested. This comparison uses
the **dynamic C baseline**, not the fixed-array `c-original-reference` tag.
The judgment is about these implementations of this small game, not a general
language ranking.

My assessment: Odin gives this game the best balance of direct gameplay code and
convenient data handling. Zig makes fallible operations and cleanup clearest.
C remains easy to follow, but requires the most collection machinery.

| Language | Strengths visible here | Costs visible here |
| --- | --- | --- |
| C | Plain structs and functions make control flow and layout straightforward. Sokol and the shared audio API are native C interfaces. | Typed lists, growth, compaction and allocator testing require custom plumbing. Error handling relies on return values and conventions. |
| Odin | Dynamic arrays, generic helpers, vector arithmetic, enum-indexed arrays and tagged events keep gameplay concise. Arrays carry their allocator. | The implicit context makes allocator selection less visible at call sites. Temporary data and optional allocation errors still require care. Our audio binding duplicates the C declarations. |
| Zig | Standard collections, explicit allocator parameters, error unions, `try`, `defer` and `errdefer` expose failure and cleanup. Built-in allocation-failure testing helps verify them. The build translates the actual audio header. | Casts, allocator arguments and propagated errors add visual noise to gameplay. Adapting the build and standard-library calls to the selected compiler required version-specific work. |

## Follow the same paths

Each application collects input, advances a fixed 120 Hz simulation, consumes
its events, and renders the current state. A collision updates health/score and
creates explosions and sound events. The host dispatches sound through the shared
C audio library; a finished-run event triggers high-score persistence. Presentation
reads game state and sends drawing commands through each language's Sokol bindings.
The simulation itself has no graphics or audio dependency.

| Path | C | Odin | Zig |
| --- | --- | --- | --- |
| Input, frame, event dispatch, resource setup/cleanup | [main.c](../implementations/c/main.c) | [main.odin](../implementations/odin/main.odin) | [main.zig](../implementations/zig/main.zig) |
| Spawn enemies; resolve collisions and scoring | [game.c](../implementations/c/game.c): `spawn_wave`, `update_bullets`, `hit_boss` | [combat.odin](../implementations/odin/game/combat.odin): corresponding procedures | [game.zig](../implementations/zig/game.zig): `spawnWave`, `updateBullets`, `hitBoss` |
| Ownership, append, replay and removal | [game.h](../implementations/c/game.h), [game.c](../implementations/c/game.c) | [types.odin](../implementations/odin/game/types.odin), [state.odin](../implementations/odin/game/state.odin) | [game.zig](../implementations/zig/game.zig): `Game`, `compact` |
| State to graphics | [presentation.c](../implementations/c/presentation.c) | [presentation.odin](../implementations/odin/presentation/presentation.odin) | [presentation.zig](../implementations/zig/presentation.zig) |

**C:** Start at `frame`, then follow `game_update` into spawning and collisions.
Appending an enemy goes through a typed helper and the common `grow` function.
Sound helpers append a `GameEvent`; the host interprets its `finished` flag or
sound fields. `game_destroy` releases the four owned lists. This is direct code,
but maintaining every typed helper and the event convention is our responsibility.
C could use collection macros or a library and a manually tagged union; the
repetition and loose event representation are choices in this implementation.

**Odin:** `frame` calls `game.update`; `combat.odin` contains spawning and collision
behavior. A generic `push` appends to built-in dynamic arrays and records allocation
errors. Sound and finished events form a tagged union consumed by a type switch.
Generic compaction replaces C's repeated loops. `delete` frees the arrays during
cleanup. Persistent allocations and temporary formatting use Odin's context;
native callbacks restore it, and temporary storage is reset after use.

**Zig:** `frame` calls `Game.update` and catches errors. Spawning uses
`ArrayList.append` with the owning game's allocator; `try` propagates failure
through the gameplay helpers. Events are a tagged union consumed by `switch`.
`deinit` releases collections, while `defer`/`errdefer` handle local cleanup and
failure paths. Resource teardown belongs in Sokol's cleanup callback: on macOS,
returning from the application loop is not a reliable shutdown boundary.

In all three, replay retains capacity and removal preserves survivor order.
Allocation failure terminates the run; no version rolls back a partially applied
step. None enforces unique ownership of `Game` or prevents stale element pointers
across collection growth. Zig's explicit errors do not remove those obligations.

## What the experiment does and does not establish

The move to dynamic storage exposed real differences in collection support and
error handling. It did not demand much beyond growable lists: there are no complex
object graphs, persistent entity handles or concurrent game-state ownership.

Our common event boundary separates gameplay from external systems well. However,
all three retain deliberately simple state machines and enemy-kind switches.
Adding thirty enemy types would require a content/behavior design decision in
every version. Odin and Zig improve how we express this architecture; changing
languages alone does not make it extensible. The shared mixer also means we
compared audio integration, not three audio-engine implementations.

All diagnostic missions matched **9,600 points at 52.75 seconds**. Recorded native
runs on the same Apple M3 Max/macOS machine gave:

| Observation | C | Odin | Zig |
| --- | ---: | ---: | ---: |
| Average FPS | 58.9 | 59.9 | 60.0 |
| Peak process RSS | 90.33 MiB | 92.84 MiB | 92.16 MiB |
| Retained game-collection storage | 1,920 bytes | 3,200 bytes | 2,552 bytes |

These were separate desktop runs with different build settings and presentation
waiting, including a C timing outlier; they establish no performance winner.
Collection sizes reflect growth policies and chosen integer widths, excluding
allocator overhead. Shared decoded audio alone is 31.15 MiB. See the recorded
[C](journal/0010_dynamic_c_comparison_baseline_20261004.md),
[Odin](journal/0012_completing_and_verifying_odin_20261004.md) and
[Zig](journal/0014_completing_and_verifying_zig_20261005.md) checks for methods and limits.

Build friction also needs attribution: Odin's LLVM issue came from this machine's
installed compiler/library mismatch; Zig required adapting to its selected API
version. Neither observation alone supports a broad ecosystem verdict.
