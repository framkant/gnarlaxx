# 0013 — Starting the Zig port

The user reported that Odin “seems to work very similar” and asked to proceed:
“time to do zig then I guess”. This accepts the Odin playtest and starts M3.

No Zig compiler was on PATH. We downloaded the official Apple Silicon Zig 0.17.0
release into ignored `build/zig/toolchain`, checked its published SHA-256
`b607e9b9234790a008116ae5bdb71c6243b84b9fb42a53a9e70fde41c06c536a`, and extracted it
locally. No system compiler installation or shell configuration was changed.
The release and checksum come from <https://ziglang.org/download/index.json>.

Current sokol-zig had moved to a newer graphics API. Revision
`ff40f04d4f51c73b2bf460d87fd2d7aa0dedc22f` contains headers byte-identical to our
pinned app, gfx, gl, glue, log and time headers. Those six official binding files
are vendored unmodified, with a small project-authored module entry point. This
preserves the shared Sokol implementation and isolates language differences.

The Zig simulation owns four `std.ArrayList` collections with an explicit
allocator. Allocation failures propagate through error unions and `try`;
`errdefer` marks a failed update/start terminal. The app will discard that failed
step's events and clean up, matching the prior ports' no-rollback contract.
Events are a tagged union; menu and volume enums remain fixed game rules. Stable
compaction preserves survivor order, and replay retains allocated capacity.

The first headless test completed three missions and replays: all reached victory
with three lives, ten waves, five drones, 9,600 points and 52.75 seconds. Storage
remained at 2,552 retained collection bytes across runs, with no leaks reported by
`std.testing.allocator`. Native integration, persistence and broader failure tests
are the next checkpoint. The earlier C reference tag remains unchanged.
