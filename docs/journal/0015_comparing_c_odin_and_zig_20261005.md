# 0015 — Comparing C, Odin and Zig

The user accepted the Zig playtest and requested the comparison:

> works fine as well. now do the comparison and present to me. brief and to the point with pros and cons per language if there are any

All three versions have now been playtested. The complete Zig implementation
is recorded in `0487a60`; the comparison uses dynamic C as requested, with the
original fixed-array C preserved at `c-original-reference`.

## Assessment

The [comparison](../comparison.md) records short source walkthroughs and the
concrete tradeoffs. C is direct and integrates naturally with the common C
libraries, but its dynamic collections and failure conventions need more manual
work. Odin's arrays, generic helpers, vector arithmetic and tagged events keep
gameplay concise, with allocator context and temporary lifetimes less visible
at call sites. Zig exposes allocation and failure through its APIs and provides
useful cleanup/testing tools, at the cost of more casts and error plumbing.

My preference for this game is Odin's balance of clarity and convenience. Zig
expresses failure handling most clearly. This is a judgment about the actual
ports, not an ecosystem or performance ranking. C's repeated list code and loose
event representation were implementation choices; other C designs are possible.

The user's earlier concern about adding thirty enemy types still applies to all
three. Their common state-machine architecture remains intentionally limited.
Dynamic storage made collection and memory-management differences visible without
turning the project into an extensible engine. Audio is shared, so this experiment
compares its integration rather than independent mixer implementations.

## Evidence and completion

Reviewed corresponding frame, spawn, collision, event, allocation and cleanup
paths, and the verification recorded in entries 0010, 0012 and 0014. All versions
matched the diagnostic mission's 9,600 points and 52.75-second mission time.
Separate desktop timings and differing collection policies do not justify a
language performance ranking. No new gameplay or timing tests are needed for this
documentation-only change.

Updated the plan and repository overview to record user acceptance of Zig and
completion of M4. The planned implementation and comparison work is complete;
no further architecture changes or scripting experiment were requested.
