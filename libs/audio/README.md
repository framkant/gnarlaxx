# Shared audio

A small C library local to Gnarlaxx. It owns WAV/MP3 decoding, 24 effect voices,
looping music, linear resampling, volume/pause, and Sokol push output. Game sound
IDs, filenames, trim durations, and voice protection are supplied by the caller.
The C implementation configures them in `implementations/c/sound_bank.c`.

Build it alone on macOS, without the game or window/graphics libraries:

```sh
cmake -S libs/audio -B build/audio -DCMAKE_BUILD_TYPE=Release
cmake --build build/audio -j
```

This produces `build/audio/libgnarlaxx_audio.a`. The root build also supplies the
`gnarlaxx_audio` CMake target. Dependencies use the existing pinned files in
`vendor/dr_libs` and `vendor/sokol`; original code is covered by the root MIT
license and third-party notices remain in `vendor`.

## C interface and ownership

Include `gna_audio.h`, or bind its C functions from Odin/Zig. The interface uses
an opaque pointer, fixed-width integers, floats, and a descriptor containing a
borrowed C string, a double, and an integer flag. There are no C game structs or
Sokol structs in the interface. Zig can import the header; Odin can declare the
same C layout and foreign procedures. Bindings will be verified with each port.

1. `gna_create` decodes mono WAV effects and optional stereo MP3 music. Descriptor
   indices become sound IDs. It consumes path strings during the call; callers
   can release their paths and descriptor array afterward. Failure returns NULL,
   frees partial allocations, and writes a diagnostic to the caller's buffer.
2. `gna_device_open` opens stereo output. Call `gna_device_pump` once per frame.
   If opening fails, the mixer remains valid and the game may continue silently.
3. `gna_play`, `gna_stop_effects`, `gna_set_volume`, and `gna_set_paused` control
   playback. Volumes start at 1. A full voice pool replaces the nonprotected voice
   furthest through its source; if all voices are protected, play returns 0.
   Effects have a 20 ms fade at their natural or configured end.
4. `gna_destroy` closes any owned device and frees all decoded samples and state.
   Destroy exactly once; the pointer is then invalid. Destroying NULL is harmless.

All operations run on the application thread; Sokol consumes the pushed queue on
its audio thread. Only one context can own a device at a time. Other contexts can
mix offline with `gna_mix` into caller-owned interleaved stereo float buffers.
Pause writes silence without advancing cursors; an already queued tail may play.
Do not call `gna_mix` alongside device pumping for the same context.

The archive contains the Sokol **audio** implementation and dr_wav/dr_mp3. Link
`AudioToolbox` on macOS and do not also instantiate those implementations in the
caller. The game instantiates its own Sokol app/graphics code separately. The
library has no Sokol app entry point, Metal dependency, or game asset paths.

The root `shared_audio` test exercises this public API without opening a device,
including synthetic PCM expectations, real assets, looping, and failure cleanup.
