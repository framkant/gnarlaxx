# Shared assets

The first asset set is ready for the C, Odin, and Zig implementations. It uses
downloaded pixel art with small scripted adaptations; no image generation was
needed. Open [preview.html](preview.html) directly in a browser to inspect the
art and play the audio. The scene is an asset composition, not a running game.

## Sources and credits

| Asset | Creator and source | License | Local original |
| --- | --- | --- | --- |
| Sprites and space backgrounds | GrafxKid, [Arcade Space Shooter Game Assets](https://opengameart.org/content/arcade-space-shooter-game-assets) | [CC0-1.0](licenses/CC0-1.0.txt); credit GrafxKid as requested | `source/grafxkid/arcade_space_shooter.png` |
| Eight sound effects | Kenney, [Sci-fi Sounds 1.0](https://kenney.nl/assets/sci-fi-sounds) | [Upstream CC0 notice](licenses/kenney-sci-fi-sounds.txt) | Selected original Ogg files in `source/kenney/` |
| Music | HydroGene, [8-bit Epic Space Shooter Music](https://opengameart.org/content/8-bit-epic-space-shooter-music) | [CC0-1.0](licenses/CC0-1.0.txt) | `audio/music.mp3`, unchanged |
| Bitmap font | Daniel Hepper / Marcel Sondaar / IBM, [font8x8](https://github.com/dhepper/font8x8) | Public domain; notice retained in the original header | `source/font8x8/font8x8_basic.h` |
| Intro voice lines | Project text synthesized with [eSpeak NG 1.52.0](https://github.com/espeak-ng/espeak-ng/releases/tag/1.52.0), built-in `en-us` voice | Project-generated speech; eSpeak NG itself is GPL-3.0-or-later and is not bundled or linked into the game | `audio/intro_warning.wav`, `audio/intro_go.wav` |

`sources.json` records download URLs, retrieval date, and original-file SHA-256
hashes. The selected originals are checked in, so normal asset rebuilding does
not need network access. No license for the game's source code is chosen here.

## Runtime files and conventions

- `graphics/sprites.png`: one 512 × 512 RGBA atlas containing 34 named sprites.
  `manifest.json` gives rectangles as `[x, y, width, height]`, in pixels from the
  top-left. Use nearest-neighbor sampling and straight-alpha blending. There
  is padding between sprites; no mipmaps are needed.
- Player and ordinary enemies occupy 32 × 32 cells. The original 16 px art is
  enlarged 2× without smoothing. The player exhaust is separate; draw it below
  the ship and alternate its two frames.
- The boss body is 96 × 96. Gun pods and exposed core are independent sprites.
  The manifest includes starting offsets relative to the body's top-left.
  Gameplay can retract the pods, hide destroyed parts, and reveal the core.
  The pilot is a simple reuse of the green drone artwork.
- `stars_far_0..3` and `stars_near_0..3` form two repeating 2 × 2 tile patterns
  with 32 px tiles. The dim far layer has a dark fill; the near layer has
  transparency. Scroll them at different speeds.
- `graphics/font.png`: a white, tintable 8 × 8 bitmap font, 16 columns, ASCII
  codepoints 0–127. Printable ASCII is sufficient for the planned UI.
- `graphics/title.png` and `graphics/level-cleared.png`: simple lettering made
  from the same font, also included in the sprite atlas.
- `audio/*.wav`: mono, 44,100 Hz, signed 16-bit PCM effects and voice lines.
  The manifest records exact frame counts. Mix them at playback time; eight
  simultaneous effects is a mixer requirement, not an asset-file property.
- `audio/music.mp3`: the original stereo 44,100 Hz track, approximately 82.3
  seconds. The author describes it as seamless. The eventual decoder must
  respect MP3 encoder delay/padding; verify the loop by listening in-game.

Sound mapping:

| Game event | WAV | Kenney original |
| --- | --- | --- |
| Player shot | `player_shot.wav` | `laserRetro_000.ogg` |
| Enemy shot | `enemy_shot.wav` | `laserSmall_001.ogg` |
| Hit / damage | `hit.wav` | `impactMetal_000.ogg` |
| Enemy destroyed | `explosion.wav` | `explosionCrunch_000.ogg` |
| Boss destroyed | `boss_explosion.wav` | `lowFrequency_explosion_000.ogg` |
| Attack warning | `warning.wav` | `computerNoise_000.ogg` |
| Menu confirmation | `menu_confirm.wav` | `forceField_000.ogg` |
| Boss ram | `boss_ram.wav` | `thrusterFire_000.ogg` |

## Adaptations and regeneration

`tools/build_assets.py` removes the source sheet's olive background, extracts
frames, scales sprites, assembles the boss from existing enemy parts and simple
rectangles, dims/separates the star layers, rasterizes the font, and makes the
logo, level-clear lettering, atlas, previews, manifest, and checksums. It also
converts selected Ogg effects to PCM WAV using ffmpeg. The upstream files remain
unchanged.

From the repository root, with Python 3, Pillow 9.1 or newer, and ffmpeg installed:

```sh
python3 tools/build_assets.py
```

The checked-in outputs let each game implementation use the assets without a
Python, Pillow, ffmpeg, or speech-engine runtime dependency. Normal rebuilding
retains the checked-in voice WAVs. To regenerate those too, use eSpeak NG 1.52.0:

```sh
python3 tools/build_assets.py --espeak /path/to/espeak-ng
```

The script records the two sentences in `VOICE` and uses `-v en-us -s 145 -p 32`.
For an uninstalled eSpeak build, set `ESPEAK_DATA_PATH` to its build directory.
Only the generated speech is stored here, not the synthesizer. The voice is
deliberately robotic; the awkward English comes from the agreed mission text.

## Validation and remaining integration

The prepared images have been visually inspected. Atlas rectangles, transparent
backgrounds, input hashes, and PCM format are checked; all audio decodes with
ffmpeg. Rebuilding produces the same runtime-file hashes in this environment.

Actual audio balance, perceived loop continuity, animation timing, and collision
shapes still need to be checked in the running game. This package supplies all
planned asset categories; it does not complete M0's Sokol/audio integration.
