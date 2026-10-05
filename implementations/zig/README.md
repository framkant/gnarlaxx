# Zig implementation

The same single mission as the dynamic C reference, with Zig gameplay,
presentation, Sokol rendering calls and score persistence. The common assets,
C audio library, PNG decoder and native Sokol platform glue are shared.

## Build and play

Verified with **Zig 0.17.0** on Apple Silicon macOS. Requires CMake and Xcode
command-line tools; the convenience wrapper also needs Python 3. Dependencies
are vendored and pinned. After installing the compiler, builds need no downloads.

```sh
python3 tools/build_zig.py --test
./build/zig/release/bin/gnarlaxx

python3 tools/build_zig.py --debug --test
./build/zig/debug/bin/gnarlaxx
```

The wrapper uses Zig on PATH, or the project-local compiler already downloaded
at `build/zig/toolchain/zig-aarch64-macos-0.17.0/zig`. Override with `--zig PATH`.
It checks the compiler version and keeps both Zig caches inside ignored `build`.
The actual build is described in the root `build.zig`; the wrapper only selects
paths and options. With Zig 0.17.0 installed, the equivalent native commands are:

```sh
zig build install test -Doptimize=safe --prefix build/zig/release
zig build install test -Doptimize=debug --prefix build/zig/debug
```

`safe` is Zig 0.17's optimized mode with runtime safety checks; `debug` enables
Sokol validation and a separate debug allocator for application-owned memory.
Both retain bounds checks. Tests use `std.testing.allocator` for leak detection.
The `run` build step starts the game; pass game options directly to the executable.

Zig's build translates `libs/audio/gna_audio.h` into an imported module, keeping
the audio interface tied to its actual C declaration. CMake builds the three
existing native libraries with Apple Clang. The `libsokol_odin.a` archive name
predates this port: it is only the shared platform glue with `SOKOL_NO_ENTRY`,
not an Odin implementation. No C or Odin gameplay code is linked.

To reproduce the local compiler setup without changing system tools, download
the official [Zig 0.17.0 Apple Silicon archive](https://ziglang.org/download/0.17.0/zig-aarch64-macos-0.17.0.tar.xz)
into `build/zig/toolchain` and extract it there. The SHA-256 from the
[official release index](https://ziglang.org/download/index.json) is:

```
b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a
```

Other machines should use their matching Zig 0.17.0 binary. The compiler itself
is not committed or required by the built game. This port intentionally pins a
release; other Zig versions have not been verified.

## Controls and diagnostics

WASD/arrows move, Space fires, Enter selects/replays, Escape pauses or returns,
V opens sound settings, and Q leaves a paused run. Losing focus pauses play.
Graphics use the same 400×500 target and integer nearest-neighbor scaling.

The versions share `~/Library/Application Support/Gnarlaxx/scores.txt` and the
`GNARLAXX 1` format with five descending scores. Use a separate path for isolated
playtests; concurrent score writers are outside this small experiment.

```sh
./build/zig/release/bin/gnarlaxx --scores /tmp/gnarlaxx-zig-scores.txt
./build/zig/release/bin/gnarlaxx --demo --mute --frames 3700 --capture /tmp/zig-victory.png
./build/zig/debug/bin/gnarlaxx --scene core --frames 30 --capture /tmp/zig-core.png
```

`--demo` uses the same invulnerable diagnostic autopilot as C and Odin. `--scene`
accepts `menu|briefing|play|boss|core|pause|victory`. Both disable score saving.
`--capture` requires a frame limit. `--assets PATH` overrides the embedded asset
location; rebuild or supply it if the checkout moves. `--help` lists all options.

## Source map and ownership

- `game.zig`: simulation and its tests. Owns four `std.ArrayList` values through
  an explicit allocator. Appends use `try`; failed updates/start mark the run
  terminal with `errdefer`. No rollback is attempted; the host discards failed
  steps' events and shuts down. Restart keeps capacity, compaction preserves
  order, and `deinit` frees all lists. Do not copy live owning state or retain
  element pointers across growth.
- `properties.zig` and `assets.zig`: tuning and generated sprite metadata.
  Dimensions and formation geometry derive from the same properties as C.
- `main.zig`: input, fixed 120 Hz updates, events, diagnostics and lifetime.
  The Sokol cleanup callback releases game, audio, graphics and score-path
  ownership because macOS Sokol may exit without returning from `sapp.run`.
- `renderer.zig` and `presentation.zig`: Sokol graphics calls and game-specific
  drawing. UI formatting uses short stack buffers, without per-frame allocation.
- `audio.zig`: game sound descriptors around the translated C API. A short-lived
  arena owns the paths during decoding. `scores.zig`: explicit `std.Io` and
  allocator parameters, checked parsing and temporary-file/rename replacement.

Tests cover full missions and replay, controls/menu flow, lives and collisions,
all boss phases, growth with forced relocation, every stress-workload allocation
failure, failed-update cleanup, score persistence, the real audio ABI, and input
edges/focus pause. This is still the deliberately small learning implementation.
Walkthroughs and the language comparison remain the later M4 work.

Regenerate the checked-in geometry after changing the common manifest:

```sh
python3 tools/generate_zig_assets.py
zig fmt --check implementations/zig build.zig
```
