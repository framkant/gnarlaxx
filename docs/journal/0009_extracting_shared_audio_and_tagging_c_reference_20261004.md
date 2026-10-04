# 0009 — Extracting shared audio and tagging the C reference

Date: 2026-10-04

Following the instruction in entry 0008, extracted the existing audio layer to
`libs/audio` and integrated it back into the C game. The annotated tag
`c-original-reference` marks this verified checkpoint, before dynamic game state.

## Boundary and ownership

The library provides an opaque `GnaAudio` context through `gna_audio.h`. Callers
supply mono WAV descriptors and an optional looping stereo MP3. Descriptors carry
clip duration and voice-protection policy; game sound IDs and filenames stay in
`implementations/c/sounds.h` and `sound_bank.c`. The library owns decoding, its
24-voice mixer, resampling, volume/pause, and Sokol push output. It has no graphics,
window, or game-state dependency. All calls remain on the application thread.

Creation consumes borrowed paths immediately, returns a handle, and frees partial
allocations on failure. Destruction closes its device and frees its samples and
state. The small C API uses ordinary C-compatible scalar types and an explicit
descriptor layout; it does not expose mixer structs to the future ports.

Sokol audio and dr_wav/dr_mp3 implementations now belong exclusively to the audio
archive. The C game still owns Sokol app/graphics. A separate CMake build can make
the audio archive without the game; its only macOS framework is AudioToolbox.
Odin and Zig binding integration will be verified during their implementations.

## Verification

- Release and AddressSanitizer/UndefinedBehaviorSanitizer builds passed both the
  existing game/persistence tests and the new public audio API tests.
- Synthetic PCM checks cover eight simultaneous voices, exact resampling values,
  pause/no cursor advance, trimming, protected voices, replacement when full,
  clipping, mute, invalid arguments, and partial decode failure cleanup.
- Real assets decode and mix, and a full MP3 loop reproduces its initial samples.
- A temporary harness compared 1,048,576 stereo frames from the old and extracted
  mixers, alternating 44.1/48 kHz, changing volumes, pausing, and playing every sound
  type. PCM hashes matched exactly: `92dc595140ad602b`.
- The standalone `cmake -S libs/audio -B build/audio` build succeeded.
- A native 90-frame core diagnostic opened Metal and the shared library's 44.1 kHz
  audio device, pumped muted audio, captured the game target, and shut down normally.
  Decoded audio remains 31.15 MiB and fixed game state remains 14,500 bytes.

The temporary PCM comparison and native capture are under ignored
`build/audio-extraction-check/`. The permanent tests exercise the public API.

## Reference boundary

The tag preserves fixed arrays for game entities and events, and the original
mission and behavior. Dynamic C collections are the next checkpoint and will be
the implementation baseline for comparing Odin and Zig. The shared C audio code
is common infrastructure and will not count as a language-specific implementation
of their game logic.
