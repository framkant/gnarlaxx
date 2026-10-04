# Gnarlaxx: a small game for comparing C, Odin, and Zig

## Purpose and boundaries

Build one playable level of a classic vertical shoot 'em up, then implement the
same game idiomatically in C, Odin, and Zig.

The main learning goal is how each language expresses the game, particularly
the interaction between graphics, audio, input, gameplay, and application state.
Identify language tradeoffs where the implementations provide concrete evidence.
Rough performance and resource measurements are useful supporting information.

This is a small, disposable learning project. Cut reasonable corners and keep
the code easy to follow. Production polish, an extensible engine, and an
architecture for future development are outside the scope.

## Implementation approach

- Prefer Sokol; the user already uses it. Check the necessary graphics, input,
  and audio integration during setup. If audio through Sokol is impractical for
  this scope, use miniaudio.
- Prefer the same graphics and audio libraries across versions so framework
  differences do not dominate the language comparison.
- Keep platform work minimal. Start with a native window on the current macOS
  development machine; additional platforms are outside the initial scope.
- Default order: C, then Odin, then Zig. C becomes the first playable reference.
  A prototype in another language, including JavaScript/HTML, is permitted if
  useful, but is not a required milestone.
- Share assets and gameplay behavior. Match appearance, sound, and controls
  while allowing idiomatic organization, data structures, resource ownership,
  and error handling in each language.
- Implement gameplay in each language. Library bindings are fine; wrapping one
  shared C game would miss the learning goal.
- Share a small local C audio library for decoding, mixing, and Sokol output.
  Keep gameplay sound choices in each implementation and use the library through
  its C interface. This extraction stays in this repository.
- Preserve the post-audio-extraction version with fixed game arrays as the
  annotated `c-original-reference` tag, the canonical C reference for the original
  task. Then make C's transient game collections dynamic before starting the ports.
  Odin and Zig will be compared against that dynamic version, including ownership,
  growth/removal, allocation failure, reset, and cleanup. Keep fixed-size values
  where the rules actually fix their size, such as the five high scores.
- Resolve minor tuning details during implementation. Commit to Git reasonably
  often, using small, meaningful commits at coherent checkpoints.

## Presentation and assets

- Upward-scrolling, layered 2D graphics with parallax.
- Use 32 × 32 px tiles as the base grid; larger sprites can span tiles.
- Render in full color, including when source artwork uses a palette.
- Render to a 400 × 500 target with integer scaling. Default to 2× in an
  800 × 1000 window.
- Show banking sprites when the player moves left or right.
- Player bullets are small, bluish, and fast. Enemy bullets have a yellow/red
  glow and move slowly enough to evade.
- Find and download a suitable free, openly licensed sprite/tile sheet first.
  If none fits, make functional assets using image generation and scripts.
  Ugly but readable is acceptable.
- Source or generate a title logo and simple retro level-clear graphics.
- Use the simplest suitable font rendering, such as a bitmap font.
- Keep source and license/attribution information with downloaded assets. Reuse
  the same assets in all implementations.

## Audio

- Background music using MP3 or Ogg; supporting both formats is unnecessary.
- One-shot WAV effects, with at least eight effects playing simultaneously in
  addition to the music.
- Master, music, and sound-effect volume controls with minimal UI.
- Deliberately bad-English voice-over for the opening mission text.
- Use simple available or generated audio; sound production is not a separate
  polish project.

## Game flow

1. Main menu with Start, High Scores, and Quit.
2. Starting fades through black into gameplay. The player ship enters with a
   classic blinking invulnerability effect.
3. Show the mission text with deliberately bad-English voice-over:
   “Enemy Boss reported to prepare invasion” and “you must stopp him! go!”
4. Play one scripted level: ten pawn waves and five kamikaze drones, then the
   boss. Exact timing and interleaving can be tuned.
5. Defeating the boss shows a retro “Level cleared” message, awards a score
   bonus, and leads to a result/replay flow. “Ready for the next mission” may
   remain as flavor text; there is only one playable mission.
6. Losing all lives ends the run and offers a route to replay or the menu.

### Player

- WASD movement with acceleration and drag, including a little drift after
  releasing a key. Keep the ship inside the play area.
- Hold Space to fire.
- Three lives. A damaging collision costs one life, followed by brief blinking
  invulnerability when play continues.
- No pickups or weapon upgrades.
- Minimal HUD showing score and remaining lives.

### Enemies

**Pawn:** Ten waves of five simple enemies following formation patterns. Keep
their behavior uncomplicated; use simple enemy shots where appropriate.

**Kamikaze drone:** Five appear during the level. Each enters, blinks to signal
its attack, then rapidly pursues the player and tries to collide with them.

**Boss:** Appears after the pawn waves and drones have been dealt with. It looks
like a large variant of the drone and roams the top of the screen.

- Blinks red before firing an automatic burst across an arc.
- Alternates firing with a ramming attack: retracts its guns, attempts to ram
  the player, then extends its guns and repeats the pattern.
- Left and right gun holders each require ten player hits to destroy. Both
  must be destroyed before the core can be damaged.
- The boss then opens its core, exposing a third gun and the pilot. It fires
  more intensely in a visibly stressed final phase.
- The exposed core requires ten player hits to destroy the boss.

### Minimal supporting systems

- Pause/resume with gameplay frozen while paused; Escape is the default key.
- A small local high-score list saved between sessions and accessible from
  the menu. A missing or unreadable score file starts an empty list.
- Simple scoring for destroyed enemies and a boss-clear bonus. Choose values
  during the first implementation and retain them in the ports.
- Straightforward collision shapes, enemy state machines, and level scheduling
  that make the interaction of systems easy to see.

## Milestones

Current status (2026-10-04): M0 is complete. The first playable C version of M1
is built and tested, including native rendering/audio, the complete mission,
menus, pause, and score persistence. User playtesting and the properties cleanup
are complete. M1a audio extraction is verified and preserved as
`c-original-reference`; dynamic C state is next before the Odin and Zig ports.
See the [C build notes](implementations/c/README.md)
and [development journal](docs/journal/README.md). Continue adding numbered journal
entries at meaningful checkpoints alongside regular Git commits.

### M0: establish the smallest workable foundation

- Check Sokol integration for C, Odin, and Zig sufficiently to confirm the
  shared approach. Decide whether audio needs miniaudio.
- Select dependencies and record versions and minimal build/run steps.
- Acquire or generate shared graphics, logo, font, music, effects, and intro
  voice-over. Prefer functional assets over time spent polishing them.
- Confirm rendering, integer scaling, input, and audio in the first
  implementation before building out the level.

### M1: playable reference implementation

- Implement the complete single-level game, defaulting to C.
- Exercise the menu-to-game flow, loss and victory, boss phases, pause/resume,
  audio mixing, volume controls, and high-score persistence.
- Take rough performance and resource measurements on the development machine.
  Note the build configuration and measurement method; keep this lightweight.
- Iterate with the user until the scope and behavior are satisfactory. This
  version becomes the behavioral reference for the ports.

### M1a: shared audio and the original C reference

- Extract the audio layer as a local library with a small C interface and explicit
  resource lifetime. Keep it independent of the C game's types and asset names.
- Integrate it back into C and verify decoding, mixing, playback, pause, volumes,
  and shutdown. Record the checked version with the annotated tag
  `c-original-reference` before changing the fixed game collections.

### M1b: dynamic C comparison baseline

- Replace fixed-capacity transient game collections with collections that grow
  as needed. Make ownership, removal, allocation failures, reset, and teardown
  explicit while preserving the visible game and mission rules.
- Verify growth beyond the old limits, lifetime behavior, and complete gameplay.
  This version becomes the implementation baseline for M2 and M3; the tag remains
  the historical reference for the original task.

### M2: Odin implementation

- Reimplement the dynamic reference game idiomatically in Odin, using the same
  assets and shared audio library, with Odin's own gameplay and collections.
- Verify equivalent gameplay and presentation. Take comparable rough measurements.

### M3: Zig implementation

- Reimplement the dynamic reference game idiomatically in Zig under the same
  constraints, using the shared audio library and Zig's own gameplay and collections.
- Verify equivalent gameplay and presentation. Take comparable rough measurements.

### M4: walkthroughs and language comparison

Write the learning material after implementation so it refers to actual code
and observed tradeoffs. During implementation, keep practical build/run
instructions and brief notes needed to preserve useful observations.

- Give a short walkthrough of each implementation.
- Compare corresponding paths: a frame from input to rendering, enemy spawning,
  a collision triggering sound and scoring, and resource setup/cleanup.
- Explain how graphics, audio, gameplay, and state communicate in each version.
- Discuss concrete differences in organization, data modeling, memory/resource
  management, error handling, and library integration where they matter.
- Include rough measurements with their limits. Distinguish language effects
  from library, implementation, and build differences; avoid unsupported rankings.

## Acceptance

Each version is playable with graphics and sound in place. It supports the
specified mission, movement and firing, three lives, all enemies and boss
phases, loss and victory, pause/resume, volume controls, and persistent high
scores. The versions share the same visible game while expressing its internals
idiomatically. Each has minimal reproducible build/run instructions.

After implementation, the walkthroughs and comparison explain the main system
interactions and tradeoffs with references to the code.

## Possible later experiment

After evaluating the implementations, decide whether another learning experiment
is worthwhile. Embedding a scripting language to live-code enemy behavior is a
possibility, not part of this plan's acceptance criteria.
