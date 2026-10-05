# Independent fresh-agent retrospective

Reviewed on 2026-10-05 at `26b75a2`. This review was requested specifically to
assess whether human interventions helped or harmed the work. It was conducted
in a fresh agent context, without inheriting the implementation agent's verdict.
That is independence of context, not independent experimental evidence: the
journals were written by the implementation agent, quoted conversations are
selected records, and this reviewer belongs to the same model family. Human
effort, omitted exchanges and the outcome without intervention remain unknown.

**The recorded steering mostly improved the learning exercise and the clarity of
the code. Its effect on the smallest playable game was mixed: some requests
improved explanation or acceptance, while others deliberately added work after
playability had been achieved.** The evidence does not show repeated human rescue
of a failing implementation. It also does not establish that an unattended agent
would have produced the same result from the initial brief.

The starting [plan at `0ec4bd7`](https://github.com/framkant/gnarlaxx/blob/0ec4bd7/plan.md)
was rough in presentation and implementation choices, but quite specific about
resolution, audio, enemy counts and boss behavior. It already requested language
ports, comparison and iteration with the user. The user then requested questions
and a revised plan before implementation ([entry 0001](journal/0001_from_rough_plan_to_better_plan_20261004.md)).
This case therefore tests a rough brief developed through collaboration, rather
than an unchanged rough brief executed without discussion. Requiring a much
stricter initial specification next time would change that experiment.

**Interventions and their observed effects**

The categories matter: a correction is evidence of different friction from a
preference, acceptance decision or new research question.

| Intervention and category | Assessment against the game, learning and simplicity |
| --- | --- |
| Choose C/Odin/Zig, prefer Sokol, constrain the mission, clarify controls/lives/persistence and add pause — **clarifications, preferences and small additions** ([0001](journal/0001_from_rough_plan_to_better_plan_20261004.md), `6d92d9e`) | Positive alignment: these settle real choices and constrain polish. No evidence establishes which answers were indispensable. The original plan already contained many requirements; the agent should distinguish missing information from asking the user to restate it. |
| Restate the asset approach — **reported correction** ([0001](journal/0001_from_rough_plan_to_better_plan_20261004.md)) | The journal admits an unnecessary question. This indicates avoidable user effort, not a demonstrated failed asset implementation. The original committed plan says “download or generate,” so the stronger “download first” preference cannot be fully reconstructed from that file alone. |
| Request public repository, license, README and journal — **publication and recording scope** ([0003](journal/0003_preparing_public_repository_20261004.md), `b872fbb`) | Positive for sharing and retrospective traceability; no direct gameplay improvement. The journal is the main reason intervention analysis is possible, although its first entries were reconstructed afterward. |
| Ask for the properties behind unexplained numbers — **code-quality correction/preference** ([0006](journal/0006_expressing_geometry_through_properties_20261004.md), `f0f346a`) | Positive for understanding: formation spacing is derived, and drawing/collision geometry shares asset offsets. No demonstrated gameplay improvement was needed. Mixed for simplicity: the agent also created a 127-line central tuning header and coupled some gameplay dimensions to sprite dimensions. Those are implementation choices, not a requirement to abstract everything. |
| Ask for architectural criticism and discuss thirty enemy types, explicitly without requesting changes — **reflection** ([0007](journal/0007_reflecting_on_c_architecture_20261004.md), `ddf633a`) | Positive learning with little implementation risk. The commit changes only the journal and index. The agent correctly preserved the small game's architecture instead of treating speculative extensibility as a new requirement. |
| Extract a local shared audio library — **architectural scope change** ([0008](journal/0008_shared_audio_and_dynamic_comparison_scope_20261004.md), `9ce2512`) | Positive reuse across three actual clients and a clearer boundary between game sound choices and mixing/output. It adds an API and binding work; any net time saving is unmeasured. It also narrows the comparison to audio integration, excluding independent mixer implementations. |
| Preserve fixed C, then require dynamic collections — **experimental scope expansion** ([0010](journal/0010_dynamic_c_comparison_baseline_20261004.md), `20fbf91`) | Positive for studying allocation, errors and ownership. It introduces complexity and failure paths without a demonstrated capacity problem in this mission. That is justified research scope, not proof that the original fixed arrays were unsound. It changes which language strengths the workload exposes. |
| Playtest C, Odin and Zig and approve progress — **acceptance and feedback** ([0006](journal/0006_expressing_geometry_through_properties_20261004.md), [0013](journal/0013_starting_the_zig_port_20261005.md), [0015](journal/0015_comparing_c_odin_and_zig_20261005.md)) | Positive evidence of perceived playability and similarity, complementing the invulnerable autopilot. No systematic difficulty assessment, playtest duration or gameplay defect list was recorded. These approvals should not be counted as corrective interventions. |
| Request slides; challenge broader conclusions; clarify the workflow thesis; ask for usage/cost analysis — **presentation, critical review and retrospective scope** ([0016–0020](journal/README.md)) | Positive for communicating results and exposing evidential limits. These requests add work beyond playable implementations. The broader challenge led to actual build measurements and clearer limits on language rankings. The late README clarification also reveals that the workflow hypothesis was not operationally measured from the start. |

**What the artifacts support, and where the account needs qualification**

The properties change is more than renaming: [`game.c`](../implementations/c/game.c)
contains `formation_x`, `game_boss_gun` and `game_boss_core`, and
[`properties.h`](../implementations/c/properties.h) separates authored values from
derived geometry. But `f0f346a` changed 12 files with 522 insertions and 189 deletions.
That breadth supports the agent's own admission that it moved too many single-use
values away from their context. It does not demonstrate that the refactor was
harmful; the tradeoff is reduced duplication versus more navigation and asset
coupling. Future maintenance effort was not measured.

Audio extraction is substantive, bounded reuse:
[`gna_audio.h`](../libs/audio/gna_audio.h) exposes an opaque owned context, borrowed
input paths, explicit destruction and device-independent mixing; game sound names
remain outside it. The old/new PCM trace files still present locally both report
`92dc595140ad602b`. The properties comparison likewise retains matching before/after
simulation and drawing-command hashes. I inspected the harness source and saved
results; I did not independently rerun those historical comparisons. They support
equivalence for the sampled scenarios, not every possible run.

The dynamic work is also real rather than merely documented. C has explicit
growth, capacity reuse and destruction; Odin uses dynamic arrays and a generic
`push`; Zig uses `ArrayList`, error propagation and allocation-failure checks.
The [C memory suite](../tests/test_game_memory.c),
[Odin memory suite](../implementations/odin/game/memory_test.odin) and
[Zig tests](../implementations/zig/game.zig) force moving allocations and failures.
These are useful checks for risks introduced by this extension. Fixed-to-dynamic
C also changes iteration from reusable pool slots to survivor creation order,
as entry 0010 acknowledges; identical end scores do not prove all intermediate
collision ordering stayed identical.

There is a concrete parity-check gap. C's `test_mission_with_moving_allocations`
prints the reported 9,600 score and 52.75-second time but only asserts a score of
at least 3,750, with no exact time assertion. Odin's `mission_and_replay` and Zig's
complete-mission test assert 9,600 and approximately 52.75. The recorded matching
outcomes are credible observations, but the three regression gates are unequal.
Promoting that already-used acceptance invariant into C's test would be a small,
useful follow-up. No implementation was changed during this review.

**Workflow and experimental practice**

Planning and commits were generally proportionate. Git preserves the original
brief, a revised plan, a native foundation, first playable C, separate geometry,
audio and dynamic changes, and simulation/native checkpoints for each port. These
are reviewable boundaries even though the complete-game commits are substantial.
There is no evidence that splitting every function into a commit would help.
The `c-original-reference` tag usefully prevents the dynamic experiment from
erasing the fixed-array design. However, it includes the properties cleanup and
audio extraction; `293496a` is the earlier playable C checkpoint. Neither tag nor
commit should be described as an untouched no-intervention control. C alone also
does not complete the original brief, which already included ports and evaluation.

Testing was a strength of the agent's work: deterministic simulation boundaries,
failure injection, native render captures and user playtests address different
risks. The record identifies corrections discovered by the agent itself, including
Odin shutdown ownership and Zig score formatting ([0012](journal/0012_completing_and_verifying_odin_20261004.md),
[0014](journal/0014_completing_and_verifying_zig_20261005.md)). These should not be
credited to human debugging. An invulnerable pilot establishes mission flow,
not ordinary-player difficulty. For this review, the current Release build was
already up to date and all three C suites passed through CTest; I did not repeat
the native playtests or rebuild the ports.

Journaling preserved rationale, explicit scope changes, checks and limitations
well. Its weakness is measurement selectivity: there is no complete intervention
ledger, human-time record or failed-attempt count. Git author metadata does not
separate human edits from agent edits. Historical comparison harnesses, detailed
native logs and the build-timing driver remain in ignored `build/` directories.
That is reasonable for disposable work, but makes a fresh clone less capable of
reproducing the retrospective's strongest claims. Preserve a small evidence
bundle or reproducible commands if those claims become central; a permanent large
test framework is unnecessary.

The language comparison controls assets, broad behavior and native dependencies
sensibly, while allowing genuine differences in collection and error expression.
It does not control implementation order: Odin inherited C's design; Zig inherited
both that design and Odin's shutdown lesson. C's handwritten lists and loose
event representation are choices, not unavoidable properties of C. Conversely,
requiring dynamic lists deliberately exercises conveniences absent from the
original fixed-pool problem. Neither baseline alone is a neutral overall language
test. There is no measured model-exposure variable, so the code cannot establish
that training exposure caused complexity or friction. Repeated fresh sessions
could better test language-dependent behavior, but attributing it to training
exposure would still require evidence about that variable. This sequential port
exercise provides useful code-reading evidence.

Environment friction deserves separate attribution. The record describes blocked
native window access, an installed Odin/LLVM mismatch and an absent Zig compiler.
Local workarounds and pinned dependencies are documented; it does not establish
how much human help those issues required. The 61 automatic approval-review turns
in the usage export are not 61 human approvals or interruptions.

**Time and cost: additional work is observable; marginal value is not**

I recalculated the [usage export](measurements/session_usage_20261005.json): all
per-turn token totals and durations sum to its aggregates. It records 3 h 00 m
34 s of active main-turn time and 22 h 14 m 49 s elapsed through `6285cd7`.
The [cost notes](learning-notes.md) apply a roughly $65 Standard / $130 Fast
API-equivalent scenario to the main agent; this review checks the arithmetic,
not current pricing or a bill. Both exclude subsequent measurement/review work
and unrecorded human time.

| Recorded work bundle | Active agent turn time |
| --- | ---: |
| Properties cleanup and verification | 14 m 31 s |
| Audio extraction, reference tag and dynamic C | 19 m 27 s |
| Architecture discussion and journal recording | 2 m 10 s |
| HTML comparison presentation and checks | 15 m 34 s |

These bundles include tool use, tests, documentation and waits. They show that
steering had a material work footprint; they do not isolate the cost of each
instruction or show what would have happened without it. The three-hour total
cannot be called the cost of merely producing the first playable game. Language
turn durations likewise cannot rank productivity when scope and inherited design
differ. Build timings have a better-defined method, but compare actual wrappers,
cache states and optimization choices, not isolated language performance.

**Practical changes for a repeat**

1. Keep the rough brief. Add a short acceptance note and record the moment each
   original milestone is accepted, before deliberately extending it.
2. Log interventions in one line each: reason, resulting action, whether work was
   blocked, and approximate human minutes. Separate corrections, preferences,
   new scope, playtests and environment assistance; fewer messages is not itself
   a quality metric.
3. Keep meaningful commits, bounded tests and user playtesting. Align the few
   shared acceptance assertions across ports, and retain the small scripts or
   traces needed to reproduce claims used in the comparison.
4. State the comparison question before selecting its workload. Preserve both
   fixed and dynamic baselines, and distinguish sequential porting from independent
   agent generation. Measure attempts, settings and effort from the start if
   productivity or model familiarity is the question.

There is no recorded intervention clearly shown to make the shipped game worse.
The strongest negative effects are extra work and added complexity relative to
the original small game, mostly in service of explicitly requested learning.
The strongest positives are clearer intent, concrete ownership experiments,
human acceptance and more honest interpretation of the results. The successful
outcome supports this collaborative workflow in one small case; it leaves the
necessity of each intervention and the broader rough-plan thesis unresolved.
