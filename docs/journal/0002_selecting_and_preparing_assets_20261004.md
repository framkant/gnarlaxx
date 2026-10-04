# 0002 — Selecting and preparing shared assets

Date: 2026-10-04

## Decision

Use GrafxKid's CC0 Arcade Space Shooter Game Assets as the visual base. It is a
compact, coherent sheet with the three player poses, enemy animation frames,
shots, effects, and space backgrounds we need. This makes image generation
unnecessary for the first implementation.

Use Kenney's CC0 Sci-fi Sounds for effects, HydroGene's CC0 8-bit Epic Space
Shooter Music, and the public-domain font8x8 bitmap font. Source links, author
credits, retained notices, and input hashes are in `assets/`.

## Work performed

- Preserved the original sprite sheet and selected source files.
- Removed the sheet's olive background and enlarged its 16 px ship/enemy frames
  to 32 px cells with nearest-neighbor sampling.
- Made a simple boss from the existing green enemy and yellow parts, with
  independent gun pods, closed armor, and an exposed pilot/core. The script
  adds simple rectangles for the gun barrels and armor.
- Prepared two starfield layers as 32 px tiles, with a dim opaque far layer and
  a transparent near layer for independent scrolling.
- Packed 34 sprites into one RGBA atlas. Added a bitmap font, simple title and
  level-clear lettering, and a language-neutral JSON manifest with rectangles,
  dimensions, boss-part offsets, and audio metadata.
- Converted eight selected Ogg effects to mono 44.1 kHz, 16-bit PCM WAV. Kept
  the original music MP3 unchanged.
- Synthesized the two mission sentences using eSpeak NG 1.52.0 and converted
  them to the same WAV format. The deliberately awkward wording is retained.
- Added an asset preparation script, a static scene composition, a labeled
  contact sheet, and a local HTML preview with audio controls.

The speech engine was built in a temporary directory, not installed system-wide
or added as a game dependency. Its CMake setup tried to fetch optional Sonic
even when that feature was disabled. The temporary build file was adjusted to
skip that fetch; the speech engine code itself was unchanged.

## Validation

- Visually inspected the source sheet, prepared scene, and sprite contact sheet.
- Checked all 34 atlas rectangles for bounds, overlap, nonempty content, and
  expected transparency; checked that the olive source background was removed.
- Verified the recorded original-file hashes.
- Decoded all eleven audio files with ffmpeg. Verified the ten WAVs have the
  expected format and frame counts and contain non-silent samples.
- Checked that every local image, audio, and documentation link in the preview
  resolves to a file.
- Rebuilt the asset package and confirmed unchanged file hashes in this setup.

## Remaining work

M0's asset categories are covered. Sokol, rendering, input, and audio integration
are still pending. The preview is a composition, not implemented gameplay.
Listening in the running game must establish mix levels and music-loop
continuity; animation timings and collision shapes also remain implementation
decisions. The boss is intentionally a simple functional adaptation.
