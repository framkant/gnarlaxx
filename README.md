# Gnarlaxx

A small vertical shoot 'em up for learning how **C, Odin, and Zig** express the
same game. The focus is the interaction between graphics, audio, input, and
gameplay, and the concrete tradeoffs that appear in each implementation.

One mission, three enemy types, a multipart boss, music and effects, pause, and
local high scores. Keep it simple: this is a learning experiment, with functional
retro art and room to cut corners.

## Current state

The first **C version is playable on macOS**, using Sokol for graphics, input,
and audio. It includes the full mission, boss phases, menus, pause, volume
controls, and saved high scores. It is ready for playtesting and tuning.
Odin and Zig follow once this reference is satisfactory; code walkthroughs and
the comparison come afterward.

Build the C version on macOS with Xcode command-line tools and CMake:

```sh
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j
./build/gnarlaxx
```

Dependencies are [vendored and pinned](vendor/README.md); no network access or
asset-generation tools are required to build or run.

The image below is captured from the running C version's 400 × 500 render target.

<img src="docs/images/c-gameplay.png" width="400" height="500" alt="Running C game: enemy formation, bullets, explosion, player ship, and scrolling starfield">

## Play

| Action | Keys |
| --- | --- |
| Move / navigate menus | WASD or arrow keys |
| Fire | Hold Space |
| Select / replay | Enter |
| Pause / resume / back | Escape |
| Sound controls | V; arrows adjust master, music, or effects |
| Leave a paused run | Q |

The game also pauses when the window loses focus. Clear ten waves and five
drones, then destroy the boss's two gun holders before attacking its core.
Each boss part takes ten hits. You have three lives and brief invulnerability
after a hit.

High scores are stored in `~/Library/Application Support/Gnarlaxx/scores.txt`.
Volume settings last for the current session. See the [C build and test notes](implementations/c/README.md)
for path overrides, diagnostics, and sanitizer instructions.

## Inspect the assets

Clone the repository and open `assets/preview.html` in a browser. It works
locally without a server and includes images and audio controls. On macOS:

```sh
git clone https://github.com/framkant/gnarlaxx.git
cd gnarlaxx
open assets/preview.html
```

The package includes a sprite atlas with named rectangles, a bitmap font, title
and level-clear lettering, a music track, eight sound effects, and two robotic
voice lines. See [asset documentation and credits](assets/README.md) for formats,
sources, and optional regeneration instructions. The prepared files are checked
in; game builds do not need the asset-generation tools.

## Work trail

- [Plan and milestones](plan.md)
- [Numbered development journal](docs/journal/README.md)
- [Shared asset manifest](assets/manifest.json)

The journal records decisions, work performed, checks, and remaining questions
at meaningful checkpoints. The implementations will use shared assets and
behavior while keeping each language's code idiomatic.

## License

Original project code, documentation, and project-created asset additions are
available under the [MIT License](LICENSE). Third-party assets retain their
existing licenses: the downloaded art, music, and effects are CC0, and the bitmap
font is public domain. See [asset credits](assets/README.md) and the retained
notices in [assets/licenses](assets/licenses).
