# 0008 — Shared audio and dynamic comparison scope

Date: 2026-10-04

At `ddf633a`, Filip changed the next steps before the Odin and Zig ports. His
instruction is recorded verbatim below.

## Instruction

> Now. we will move to the next step. And here comes alreauy a change in plans: Since I know that sokol does not have a build in system for the whole audio layer and you just built a wrapper to help us out in this impl we should extract that as a small lib that the other languages can use as well. (sokol is well supported in zig and odin). 
> I assume I do not have to babysit you about that one, but first step is oc to extract and use here. And extract refers to a local extraction, not a new repo or anything.
>
> Once that is done an verified, I want you to advance the state to the C impl as well in order to make it more "sane" for the other langs to show their strong points. I mean, with static arrays etc C is at its home court. The friction usually comes with dynamic data structures and mem mgmt. be sure to tag the post-lib-extraction c impl as the a canonical ref if idiomatic C for the orig task. the updated dynamic variant will be the ones that odin and zig will be measured against?
> Question now up front, otherwise go ahead. Oh and caputre this instruction message verbatin in the journal

## Working decisions

1. Extract decoding, mixing, volume/pause controls, and Sokol device output into
   a small local C library under `libs/audio`. Give it an opaque context and a
   plain C interface that Odin and Zig can call. Game sound names, file choices,
   and per-sound playback policy remain outside the library.
2. Use the library from C, verify it, and create the annotated tag
   `c-original-reference` before changing the game collections. This preserves
   the canonical C implementation of the original small, fixed-capacity task.
3. Advance C to growing collections for enemies, bullets, explosions, and events.
   Exercise ownership, allocation failure, growth, removal, replay, and teardown.
   Keep the same level, appearance, controls, and gameplay rules.
4. Compare Odin and Zig against that dynamic C version, while allowing each
   language to express its collections and memory management idiomatically.
   The shared audio implementation is infrastructure, not evidence about which
   language expresses game logic better.

The plan now reflects this sequence. These are implementation decisions within
the requested scope; no extra clarification was needed. Extraction and dynamic
state verification will be recorded in subsequent entries.
