# 0004 — Native C foundation

Date: 2026-10-04

## Decisions and implementation

Started the native C implementation on macOS, using Sokol with Metal and
`sokol_gl` for textured quads. Graphics render into a real 400 × 500 RGBA target,
then draw to the window at the largest fitting integer scale. The default
window request is 800 × 1000 points; Retina framebuffers retain integer pixels.

Sokol audio's push interface works for this scope. A small main-thread mixer
combines looping music with up to 24 simultaneous effects/voice lines; WAV and
MP3 decoding use dr_libs. This avoids audio/gameplay shared-state locking and
keeps mixing visible for the later language comparison. Miniaudio is not needed.
Assets are decoded into memory once; the first measurement is 31.15 MiB of
decoded audio. The output mixer can resample to the actual device rate.

Vendored pinned, unmodified Sokol, dr_libs, and stb_image files with their licenses
and checksums. Confirmed official Odin and Zig bindings exist for this approach;
the ports have not been compiled. Generated a small C atlas header from the
shared JSON manifest so the game does not need a JSON parser or Python at runtime.

Only the macOS platform implementation is Objective-C. Game-facing rendering and
audio modules are C. A diagnostic capture path reads the game's own Metal render
target to PNG, without capturing the desktop.

## Verification

- CMake/Ninja debug build completed with Apple Clang 17 and no project warnings.
- Ran the native window for 90 frames: Metal rendered the title, starfield,
  bitmap text, and player sprite; Sokol reported an available audio output device.
- Captured and inspected the actual 400 × 500 render target.
- The first sandboxed launch stalled because Cocoa window services were
  unavailable. Stopped that process and successfully ran the same executable
  with native window access.

This finishes the integration foundation. Next: the complete mission, menus,
pause, score persistence, and focused simulation/mixer tests, then user playtesting.
