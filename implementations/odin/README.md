# Odin implementation

The same single mission as the dynamic C reference, implemented in Odin with
Sokol/Metal on macOS. It shares assets, native platform glue, PNG decoding and
`libs/audio`; gameplay, rendering commands, presentation and persistence are Odin.

## Build and play

Requires Odin, Python 3, CMake and Xcode command-line tools. The compiler used for
verification is `dev-2025-03:951bef4ad` with LLVM 19.1.7, on Apple Silicon macOS.
Bindings and native dependencies are pinned in `vendor`; builds do not download.

From the repository root:

```sh
python3 tools/build_odin.py
./build/odin/release/gnarlaxx

python3 tools/build_odin.py --debug --test
./build/odin/debug/gnarlaxx
```

Release uses `-o:speed`; debug enables Sokol validation and tracks Odin's
persistent allocations through shutdown. Both retain Odin bounds checks.
`--test` runs gameplay, collection ownership/failure, score-file and shared-audio
integration tests. Add it to either build configuration.

The development machine's old Homebrew Odin binary expects LLVM 19, but its
unversioned LLVM link resolves to LLVM 20. Optimized compilation then fails with
`invalid InstCombine pass parameter 'use-loop-info'`. Selecting the already
installed matching libraries for the compiler process fixes this without
changing Homebrew, symlinks or the user's shell configuration:

```sh
python3 tools/build_odin.py --test \
  --odin /opt/homebrew/Cellar/odin/2025-03/libexec/odin \
  --library-path /opt/homebrew/Cellar/llvm/19.1.7_1/lib:/opt/homebrew/Cellar/z3/4.14.1/lib
```

Those paths are specific to the development machine. A consistent Odin/LLVM
installation uses the ordinary command. The workaround runs the actual compiler
binary because macOS strips library-path variables when passing through the
Homebrew shell wrapper. The game itself requires none of these overrides.

## Controls and diagnostics

WASD/arrows move, Space fires, Enter selects/replays, Escape pauses or returns,
V opens volume controls, and Q leaves a paused run. Losing focus pauses play.
The logical canvas is 400×500 with nearest-neighbor integer scaling.

High scores share C's format and default location:
`~/Library/Application Support/Gnarlaxx/scores.txt`. Run only one game instance
when writing that shared file; simultaneous writers are outside this experiment.

```sh
./build/odin/release/gnarlaxx --scores /tmp/gnarlaxx-odin-scores.txt
./build/odin/release/gnarlaxx --demo --mute --frames 3700 --capture /tmp/odin-victory.png
./build/odin/debug/gnarlaxx --scene core --frames 30 --capture /tmp/odin-core.png
```

`--demo` is an invulnerable diagnostic autopilot. `--scene` accepts
`menu|briefing|play|boss|core|pause|victory`. Both disable score saving. `--capture`
requires a frame limit. `--assets PATH` overrides the baked-in asset location;
rebuild or supply it if the checkout moves. Use `--help` for the full option list.

## Source map and ownership

- `game/`: simulation, properties, generated geometry and headless tests. No
  Sokol imports. `Game` owns four dynamic arrays, retains capacity on replay and
  releases it on `destroy`. Do not copy a live game or retain element pointers
  across growth. Stable compaction preserves collision and draw order.
- `main.odin`: native callbacks, input, fixed 120 Hz updates, event dispatch and
  resource lifetime. Callbacks restore Odin's context. Temporary formatting and
  FFI strings use the temporary allocator, reset after initialization/each frame;
  persistent game data uses a separate allocator.
- `renderer/` and `presentation/`: Sokol graphics calls and the game-specific UI.
  `audio/`: the shared library's C ABI plus this game's sound-bank configuration.
  `scores/`: versioned file parsing and temporary-file/rename replacement.

Dynamic-array append errors put the game into a terminal allocation-error state.
There is no rollback of a partly applied simulation step; the app skips that
step's events and shuts down with an error. This deliberately matches C's failure
contract. Allocation tracking covers Odin-owned persistent data; the shared C
library has its own C tests and sanitizer coverage.

Regenerate sprite geometry only when the shared manifest changes:

```sh
python3 tools/generate_odin_assets.py
```

The small `sprite_rect` helper makes the generated constant table runtime-indexable
with the verified compiler. The complete walkthrough and language comparison
remain the later M4 milestone.
