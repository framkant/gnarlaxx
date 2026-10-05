# 0020 — Estimating cost and learning from the experiment

The user said:

> yeah it was a little sloppy (on purpose). Can you approx costs in some way? and a suggestion for the next time or for a reader of the repo from a learning perspective?

Added [cost and learning notes](../learning-notes.md), linked from the README.
Applied published GPT-6 Astra prices to the existing usage snapshot, preserving
its cutoff through the final README clarification at `6285cd7`. The main agent
comes to $64.83 at Standard API token rates or $129.67 at Fast rates. Pricing was
checked against official OpenAI documentation on 2026-10-05.

The automatic approval reviewer has a different model identifier and no price
established by the reviewed sources. Valuing its tokens at Astra rates is shown
only as a hypothetical scenario: $73.13 Standard or $146.26 Fast combined.
Neither scenario establishes the subscription charge or actual invoice. Human
time, hardware, taxes and separate tool/service fees are outside this estimate.

The central recommendation is to retain the rough brief and record the reasons
for human interventions. Distinguish agent corrections, missing information,
preferences, new scope and environment problems; record human effort as well as
agent usage. Define acceptance briefly and mark completion of the original task
before extending it. This keeps the original learning question intact while
making the outcome easier to assess.

For readers, suggested tracing the original C game before comparing ownership
across the dynamic variants. Loading and reloading wave definitions is proposed
as a practical exercise in allocation, validation and extending the design.
No implementation work is part of this checkpoint.

Validation: recalculated costs from the checked-in token totals; inspected
per-response logs to confirm zero recorded cache-write tokens and no request
above the long-context pricing threshold; checked documentation links and the
Git diff. No game tests were needed.
