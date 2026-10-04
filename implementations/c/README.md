# C implementation

The dynamic C comparison baseline targets macOS on a machine with Xcode command-line
tools and CMake. Dependencies are vendored; the build does not download anything.

From the repository root:

```sh
cmake -S . -B build/release -DCMAKE_BUILD_TYPE=Release
cmake --build build/release -j
./build/release/gnarlaxx
```

The executable defaults to the repository's asset directory recorded at build
time. If moving the executable elsewhere, copy the assets and pass `--assets`.
Scores normally live under `~/Library/Application Support/Gnarlaxx/`; use
`--scores` to choose a different file. The parent directory of an override must
already exist. For example:

```sh
./build/release/gnarlaxx --assets ./assets --scores ./build/my-scores.txt
```

See the root [README](../../README.md) for controls. Sound settings are available
from the menu or with V during play. Pause freezes the simulation and mixer;
the small audio queue may finish a few already-buffered milliseconds of sound.
Leaving the window pauses automatically. An abandoned run does not record a score.

## Checks

```sh
ctest --test-dir build/release --output-on-failure

cmake -S . -B build/sanitize -DCMAKE_BUILD_TYPE=Debug -DGNARLAXX_SANITIZE=ON
cmake --build build/sanitize -j
ctest --test-dir build/sanitize --output-on-failure
```

The test executable needs no window or audio device. It exercises the actual
simulation, mixer, and score-file code, including the complete enemy schedule,
all boss states, protected/reachable core, life loss, replay, pause, corrupt
scores, simultaneous effects, resampling, and music wraparound.
The dynamic-state checks additionally exceed the original entity/event capacities,
force storage to move on growth, fail each allocation in a stress sequence, verify
stable removal and 100 resets, and play three complete missions with tracked ownership.

The normal app needs a desktop session and permission to access native window
services. Native diagnostics can capture the game's own Metal render target:

```sh
./build/release/gnarlaxx --scene boss --demo --frames 480 --capture build/boss.png
```

`--demo` enables an invulnerable autopilot for integration checks; it does not
establish normal difficulty. `--scene` accepts `menu`, `briefing`, `play`, `boss`,
`core`, `pause`, or `victory`. Diagnostic scenes and autopilot never save scores.
`--capture` requires a positive `--frames` limit; the capture occurs at that limit.
Closing the window earlier exits normally without taking the capture. `--mute`
starts with the master volume at zero, and `--help` lists the options.

At exit, the app prints rough FPS, frame-callback wall time, process CPU time,
and peak resident memory. Frame time includes rendering/presentation waits and
is not a GPU measurement. See [journal entry 0005](../../docs/journal/0005_first_playable_c_reference_20261004.md)
for the first measurements and their limits.

## Source layout

- `main.c`: input, fixed simulation steps, sound/score events, and app lifetime.
- `game.c`: game state, movement, enemy scheduling, collisions, boss, and menus.
- `properties.h`: gameplay tuning and dimensions derived from the playfield and
  assets. Formation spacing uses the available width, side margins, and ship count;
  sprite sizes and boss part offsets come from the asset manifest.
- `presentation.c` / `renderer.c`: turn game state into sprites and text; render
  to 400 × 500, then present at integer scale with letterboxing.
- `sound_bank.c` / `sounds.h`: game sound IDs, paths, clip durations, and voice protection.
- [`libs/audio`](../../libs/audio/README.md): shared C library for decoding, mixing,
  volume/pause, and Sokol output, with an opaque interface for all three languages.
- `scores.c`: validate, sort, and save the five-entry score list.
- `platform.m` / `decoders.c`: instantiate the third-party libraries. Only the
  macOS platform glue and optional GPU capture use Objective-C.

`assets.h` is checked-in generated data. If asset geometry in the manifest changes, run
`python3 tools/generate_c_assets.py`. Formatting is described by `.clang-format`;
do not reformat the vendored files or generated header. Full code walkthroughs
and language evaluation remain deferred until the implementations are complete.

The annotated tag `c-original-reference` preserves the verified post-audio-extraction
implementation with fixed game arrays. It is the canonical C reference for the
original task. Current C uses dynamic game collections and is the comparison
baseline for Odin and Zig.

## Dynamic state contract

`Game` owns typed, contiguous lists of enemies, bullets, explosions, and events.
Each has a pointer, count, and capacity. Storage is allocated lazily, starts at eight
elements, and doubles as needed. Add functions copy their arguments by value.
Live entity pointers and indices are temporary: growth can move storage, and the
end-of-update compaction shifts elements. No game object retains a reference into
another collection across updates.

Collisions/expiry mark entries inactive; stable compaction removes them after
simulation finishes. Surviving entries remain in creation order. This differs
from the original version's reuse of the first inactive pool slot; storage indices
are not part of gameplay identity. Events remain until the host consumes them and
sets `events.count = 0`.

`game_start` resets a run while retaining allocated capacity and sound settings.
`game_destroy` frees every owned buffer and zeroes the state. A live `Game` must
not be shallow-copied or initialized a second time without destruction. The player,
single boss, fixed volume channels, and fixed high-score table remain plain values.

Allocation failure leaves existing buffers owned and valid for destruction, sets
`allocation_failed`, and makes `game_update`/start/add return false. A failed step
may be partially applied; it is terminal, with no rollback or retry contract. The
app reports the error, skips that step's events, and shuts down with a failure
status. `game_init_with_allocator` provides the small realloc-style hook used by
tests to force movement, count live bytes, and inject failures. Normal play uses
`realloc`/`free`.

At shutdown, diagnostics report the inline `Game` size and retained collection
bytes separately. This excludes allocator overhead, renderer resources, and the
shared audio library; it is not total process memory.
