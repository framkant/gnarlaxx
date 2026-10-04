# 0007 — Reflecting on the C architecture

Date: 2026-10-04

After the properties cleanup at `f0f346a`, Filip asked Codex to critique its own
architectural choices. He then asked for the question, explanation, and his
response to be recorded in the journal. The exchange below is preserved as given.

## Filip's question

> So, this is better. If you would critizise youseself, what would you say? there are not really a right and wrong here so just name a few things where you think your architecture is strong vs weak and why you made the choices you did

## Codex's explanation

> I think the strongest part is the separation of responsibilities. My biggest criticism is that the recent cleanup improved the names more than it improved the representation of the game’s concepts.
>
> - **The simulation boundary is strong.** `game.c` updates state and produces events; presentation draws that state, and the audio code consumes sound events. That makes the game easy to test without a window and gives us a useful boundary when comparing languages. It also makes the order of operations visible.
>
> - **The data model is deliberately simple.** Structs, fixed arrays, and ordinary loops make it easy to follow a bullet from creation through movement to collision. I chose that because this is one small learning project. The weakness is that full arrays silently drop things, and several loops scan inactive slots. Those are acceptable shortcuts here, but the capacity behavior could be clearer.
>
> - **The properties cleanup is only partly satisfying.** Deriving formation spacing and boss geometry removes duplicated knowledge. Moving speeds and delays into a large header mostly gives existing decisions names. `BOSS_RAM_SIDE_MARGIN` explains what a number controls, but not why that value feels good. I probably moved too many single-use values away from the code they explain; some would read better as local named constants.
>
> - **Gameplay now depends quite closely on the artwork.** Using sprite dimensions keeps drawing and geometry consistent. However, adding transparent padding to a sprite could change movement bounds or collision geometry. Explicit gameplay dimensions would give us more control. I chose the asset dimensions because we have a fixed asset set and wanted minimal duplication.
>
> - **The scene handling is the least tidy part.** Menu, briefing, play, pause, and sound settings share one update function. `paused_scene` and `sound_return` make the overlays work, but their interactions require remembering special cases. Straight branches were economical for this scope; this is where another feature would probably make the simplicity start to deteriorate.
>
> - **The module boundaries have some leaks.** For example, `game.h` includes `audio.h` because game events use its sound identifiers. The simulation needs the concept “play this sound,” but consequently sees mixer-related declarations too. A small shared events header would express that dependency more accurately.
>
> For the language comparison, I’d preserve the behavior and these broad boundaries while allowing each implementation to express them differently. Otherwise we risk comparing three translations of C rather than learning what C, Odin, and Zig each make clear or awkward.

## Filip's response

> My comments: This is ok and straigtforward, idiomatic, old school C that I would have expected from a bright kid in his late teens. No thinking forward. Getting shit done. Easy to understand.
>
> The code is easy but cumbersome to will be gnarly to add content to. How would we create 30 different enemies? Behaviors? Graphics changes? Sure, if that would have been the task up front I guess you would done more abstractions but at the cost of overengineering. Not telling you to change anything. Just interesting to see the choices being made.

## Outcome

This exchange records the tradeoff between immediate clarity and the effort of
adding substantially more content. Filip explicitly made these observations
without requesting implementation changes. This checkpoint adds only the journal
entry and its index link; the game and plan are unchanged. Validation is a review
of the recorded exchange and the documentation diff; no game tests are needed.
