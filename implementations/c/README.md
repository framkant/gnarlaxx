# C implementation

The first playable reference targets macOS on a machine with Xcode command-line
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
original task. The next stage introduces dynamic game collections; that version
will be the comparison baseline for Odin and Zig.
