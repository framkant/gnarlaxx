# 0019 — Reconstructing tokens and elapsed time

The user asked:

> can you see how many tokens we consumed to make this and how long time it took?

Local Codex session logs contain per-response token usage and completed-turn
durations. I had not inspected these when writing entry 0017. We can reconstruct
recorded effort, although it remains an uncontrolled experiment with different
work in each language stage.

## Scope and totals

These numbers cover the first plan-reading turn through the README clarification
at commit `6285cd7`: **2026-10-04 15:57:07 to 2026-10-05 14:11:56**, Stockholm time.
They include implementation, assets, verification, discussion, documentation and
the presentation. This later usage investigation is excluded.

| Recorded token usage | Tokens |
| --- | ---: |
| Main conversation: uncached input | 1,610,070 |
| Main conversation: cached input | 33,431,424 |
| Main conversation: generated output | 306,026 |
| **Main conversation total** | **35,347,520** |
| Automatic approval reviews, separately | 3,352,480 |
| **Combined total** | **38,700,000** |

The main conversation processed 35,041,494 input tokens, **95.4% cached**. Context
is counted each time it is supplied to a model response, so these are not counts
of unique text or code. Output includes tool calls and 75,876 reasoning tokens.
Cached input is already included in input; reasoning is already included in
output. These subset conventions are described in the
[OpenAI usage documentation](https://developers.openai.com/api/docs/guides/agents-api/observability).
This is a usage record, not a billing statement.

**Active agent turn time was 3 h 00 m 34 s**, summed across 19 completed main
turns. This includes tool execution, builds, tests and waits within a turn;
it excludes gaps between turns. **Calendar elapsed time was 22 h 14 m 49 s**,
including the overnight break and other gaps. Neither measures the user's
working time or pure model inference time.

For context, the Odin implementation/verification turn took **24 m 37 s** and
the Zig turn **33 m 39 s**. The initial playable C implementation turn took
**30 m 33 s**, with assets prepared beforehand and geometry cleanup, audio
extraction and dynamic storage handled afterward. These scopes differ, and the
ports inherited the existing design; the timings do not establish an intrinsic
language productivity ranking.

## Method and validation

Summed the `usage` fields in `token_usage_record`, once per unique response ID,
through the cutoff: 290 main responses and 61 automatic approval reviews in
four review threads. Every included record belongs to the same root session.
The sums match the final `thread_token_usage` snapshots in all five threads.
The older `token_count` event totals differ; they were not used or added again.

Summed `duration_ms` across distinct completed main turns. Start/end timestamps
independently agree to within 0.12 seconds in aggregate. Review durations are
not added, since they overlap the main turns.

Saved [aggregate and per-turn measurements](../measurements/session_usage_20261005.json)
without raw transcripts, account information, session paths or internal IDs.
Checked the exported arithmetic, cutoff, and journal links. No runtime tests
were needed for this documentation-only change.
