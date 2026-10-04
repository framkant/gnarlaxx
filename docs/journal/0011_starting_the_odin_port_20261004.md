# 0011 — Starting the Odin port

The user asked: “ok then. I guess it is time for odin. anything you need from me up front?”

No further decisions were needed: the dynamic C implementation is the behavior
baseline, and the extracted C audio library is shared. Gameplay, presentation,
rendering calls and score persistence are implemented in Odin. Sokol's native
platform glue and PNG decoder remain common dependencies.

The installed compiler is `dev-2025-03:951bef4ad`. We pinned the six required
official sokol-odin modules at `132fa9d26acf98cf6358a61e8baadf985196ab42`;
their accompanying C headers match our pinned Sokol headers byte for byte.
Only the bindings' library selection is patched, to use our locally built
archive. This avoids a second, potentially incompatible Sokol implementation.

The simulation uses Odin dynamic arrays with their stored allocator, explicit
append errors, stable compaction and retained capacities across restarts.
Sound and finished-run events are a tagged union. Geometry still comes from
properties and the common manifest; a generator emits the sprite metadata.

Four headless tests pass: movement/menu/pause/intro behavior, boss damage and
player lives, the complete boss phase cycle, and three full missions/replays.
All three missions finish at 9,600 points in 52.75 seconds, matching C. The Odin
test runner and a tracking allocator report no leftover game allocations.
The mission retains 3,200 bytes of collection storage (C retained 1,920 bytes);
this is an observation about these implementations and their growth policies,
not a language performance ranking. Rendering and native integration are next.
