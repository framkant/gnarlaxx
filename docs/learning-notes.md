# Cost and learning from the experiment

This was intentionally a loose experiment. A rough brief, an experienced user's
feedback, and an agent produced three playable implementations. The useful
observation is that this combination worked for this small project. We have one
case, with changing requirements and shared design work between languages, so
the result leaves the broader thesis open.

## Approximate cost

Using the recorded usage through commit `6285cd7`, the main agent's work has an
**API-equivalent token cost of about US$65 at Standard speed or US$130 at Fast
speed**. The scope includes planning, assets, implementation, verification,
discussion, documentation and the presentation. Later measurement and
retrospective work is excluded.

The official OpenAI documentation, checked on **2026-10-05**, lists GPT-6 Astra
Standard rates of $10 per million uncached input tokens, $1 for cached input,
and $50 for output. Fast mode doubles those rates.
[Source: GPT-6 Astra pricing](https://developers.openai.com/api/docs/models/gpt-6-astra).

| Main agent usage | Tokens | Standard cost, USD |
| --- | ---: | ---: |
| Uncached input | 1,610,070 | $16.10 |
| Cached input | 33,431,424 | $33.43 |
| Output, including reasoning | 306,026 | $15.30 |
| **Total** | **35,347,520** | **$64.83** |

Calculation: `(1,610,070 × 10 + 33,431,424 × 1 + 306,026 × 50) / 1,000,000`.
Cached input and reasoning are counted once. The logs record zero cache-write
tokens. The largest main request had 236,123 input tokens, below the published
272,000-token threshold for higher context pricing.

The separate approval reviewer is recorded as `codex-auto-review`; the reviewed
public documentation did not establish its token price. If we hypothetically
value its recorded usage at Astra rates too, it adds **$8.30 Standard / $16.59
Fast**, producing **$73.13 / $146.26** combined. That is an explicit pricing
assumption, not a measured reviewer charge or a bound on the actual bill.

These are token-cost scenarios. The logs used here do not establish the billed
service tier or what the user paid through their subscription or credits.
[Codex billing depends on the access and payment arrangement](https://learn.chatgpt.com/docs/pricing).
Taxes, separate tool/service charges, hardware and human time are excluded.
The recorded agent time was about three hours; the user's working time was not
measured. See the [usage record and method](journal/0019_reconstructing_tokens_and_elapsed_time_20261005.md).

## What to improve next time

**Keep the rough brief, and measure the steering.** A detailed specification
would change the question we set out to explore. A small amount of bookkeeping
would make the same informal workflow much more informative:

1. Write a short definition of done: observable behavior, target platform,
   simplicity expectations, and how the user will accept the result. Freeze a
   checkpoint when that original task is satisfied; record extensions separately.
2. For each human intervention, record its reason: correcting an agent mistake,
   resolving an ambiguity, expressing a preference, changing scope, or unblocking
   the environment. Note whether progress depended on it and roughly how many
   minutes the person spent. For example, the asset reminder addressed an
   instruction already given; requesting dynamic collections changed the task.
3. Capture model/version, effort and speed settings, compiler versions, token
   usage, active time, and failed build/test attempts from the start. For a
   stronger language comparison, use fresh sessions with the same brief, assets
   and acceptance checks, and repeat runs before drawing a ranking. Preserve the
   separate context that ports benefit from an existing design.

This would let us judge both the resulting game and how much human work was
needed to reach it. Here, the user supplied architectural criticism, scope
decisions and playtesting; those contributions are part of the successful
workflow.

## A learning exercise for readers

Start with the `c-original-reference` tag and trace one shot through input,
simulation, rendering and sound. Read the
[architecture discussion](journal/0007_reflecting_on_c_architecture_20261004.md)
alongside the code, then compare collection ownership and allocation failure
handling in the current C, Odin and Zig implementations using the
[comparison](comparison.md).

For a next exercise, load wave definitions from a file and allow reloading
between runs. Before asking an agent to implement it, predict which files and
ownership rules must change. Check that malformed data leaves the previous wave
usable and that repeated reloads release old allocations. This creates a
practical reason for dynamic storage and makes the cost of extending each design
visible. Judge the resulting code, required corrections and your understanding
of the change together. This is a proposed exercise; it has not been implemented.
