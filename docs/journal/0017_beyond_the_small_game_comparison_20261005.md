# 0017 — Beyond the small-game comparison

The user challenged how much this experiment established, and asked about build
speed, language maturity, suitable larger projects, App Store/Steam distribution,
and which language was quickest or least troublesome for an agent to produce.

## What the experiment establishes

The criticism is fair. The original game fit fixed-capacity arrays well; those
were a reasonable implementation, not something inherently unsound. We introduced
dynamic collections specifically to exercise memory management. That reveals
differences in collection and error-handling support, but cannot establish an
overall winner for game development.

My preference for Odin's expression of this game remains a preference. We have
not tested a large content pipeline, editor, object graph, concurrent ownership
or a multiplatform release. All three retained broadly the same architecture.
A possible more revealing experiment would load enemy and wave descriptions
from files and reload them during play, introducing parsing, lookup, validation
and resource lifetimes for a practical reason. No such implementation was requested.

## Measured build times

Measured the actual build workflows on the same Apple M3 Max, using Apple Clang
17, Odin `dev-2025-03:951bef4ad` with matching LLVM 19.1.7 libraries, and Zig 0.17.0.
All six debug/optimized output binaries and the compilers were verified as arm64.
The existing Python 3.7 wrapper interpreter runs under Rosetta; the native
compiler and CMake executables are arm64.

| Language | Clean optimized build, tool cache available | Optimized build after tuning edit | Debug build after tuning edit | Unchanged optimized invocation |
| --- | ---: | ---: | ---: | ---: |
| C | 3.95 s | 0.39 s | 0.33 s | 0.03 s |
| Odin | 6.01 s | 1.79 s | 1.14 s | 1.79 s |
| Zig | 13.07 s | 7.69 s | 2.43 s | 0.91 s |

Clean builds are single observations. Edits and unchanged invocations are
medians of three sequential runs. The edit changes `PLAYER_SHOT_SPEED` to three
previously unbuilt values, avoiding Zig content-cache hits for reverted source.
Each language/profile uses an isolated source copy under ignored
`build/build-timing`; the actual game files were not edited.

C uses CMake/Ninja and four jobs. The Odin and Zig wrappers configure and build
their shared libraries with CMake/Make, then compile their language code. Tests,
downloads, asset generation, copying sources and packaging are excluded. Odin's
wrapper recompiles the Odin program even when unchanged. Build orchestration and
optimization settings differ; these are practical project timings rather than
isolated compiler benchmarks. The installed Odin compiler is considerably older
than the Zig compiler, so this does not compare the latest releases of each.

Zig's first optimized build with both local and global caches empty took **73.68 s**;
debug took **70.86 s**. The table uses separate clean application/native builds
with its global tool cache retained: **13.07 s** optimized and **6.00 s** debug.
For those checks, native outputs were cleaned and the local Zig cache moved
aside. C and Odin's fresh debug builds took 2.24 s and 5.07 s. Filesystem and Apple
SDK caches were not flushed. First-use tool/cache preparation should not be
confused with the ordinary edit/build loop.

[Raw results, commands and method notes](../measurements/build_times_20261005.json)
are checked in. The measurement driver and detailed build logs remain in the
ignored scratch directory. All timed builds succeeded.

## Maturity and likely uses

Checked current primary sources on 2026-10-05. Odin has substantial production
examples including JangaFX tools and released Steam games; its FAQ distinguishes
the relatively settled language design from the still-developing compiler and
libraries. That supports using it for a desktop game with a pinned toolchain and
verified dependencies. Sources: [Odin showcase](https://odin-lang.org/showcase/),
[games](https://odin-lang.org/games/), [FAQ](https://odin-lang.org/docs/faq/).

Zig also supports shipped software: Ghostty uses a shared Zig core with native
frontends. Its current 0.17 release still changes language/build/library APIs.
I would budget for compiler migrations and validate target support early.
Sources: [Ghostty architecture](https://ghostty.org/docs/about),
[Zig 0.17 release notes](https://ziglang.org/download/0.17.0/release-notes.html).

Extrapolation, rather than a result measured here:

- C fits reusable C-ABI libraries, existing C codebases and projects prioritizing
  established vendor/platform integration. It trades convenient data modeling
  for explicit machinery and a mature implementation/tooling choice.
- Odin fits custom games, editors, simulation and graphics tools where math,
  changing collections and straightforward procedural code dominate. Its array
  programming, maps, allocator context and structure-of-arrays support would
  matter more there. See the [language overview](https://odin-lang.org/docs/overview/).
- Zig fits engine components, parsers, asset tools and systems libraries where
  explicit allocation, failure paths, compile-time specialization and cross-target
  builds matter. Our game barely exercises the compile-time tooling advantages.
  See the [Zig overview](https://ziglang.org/learn/overview/).

## Distribution implications

Steam distribution does not require integrating Steamworks features. Achievements,
cloud and other integrations need appropriate bindings or an adapter; Valve's
flat interface has C linkage but is not itself a pure-C header. This affects all
three languages, including C when using the predominantly C++ SDK.
Sources: [Steamworks SDK](https://partner.steamgames.com/doc/sdk),
[API overview](https://partner.steamgames.com/doc/sdk/api%20).

The practical Apple work is application packaging, signing, SDK compatibility,
public API use and sandbox/container integration. This repository currently
produces development executables with an absolute source-tree asset path, not
store-ready app bundles. It needs bundle-relative resource discovery and checked
platform save paths before distribution. Apple's Mac App Store requires App
Sandbox; Valve explicitly says not to enable that entitlement in Steam builds.
Those distribution profiles therefore need different entitlements.
Sources: [Apple review requirements](https://developer.apple.com/app-store/review/guidelines/),
[App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox),
[Steam platform requirements](https://partner.steamgames.com/doc/store/application/platforms).

iPhone/iPad deployment needs separate validation from macOS. Odin exposes iPhone
subtargets, while Zig 0.17 lists aarch64-ios as Tier 3. Neither is evidence that
this game's pinned compiler/bindings already provide a tested mobile release
pipeline. A signed device/TestFlight proof would be an early project decision.
Sources: [Odin target constants](https://pkg.odin-lang.org/base/builtin/),
[Zig target support](https://ziglang.org/learn/platform-support/aarch64-ios/).

## Agent effort: what was actually recorded

There is no controlled record of active generation time, token count, compile
attempts or debugging time per language. Git checkpoint intervals include pauses,
verification and different work. C also established the game and assets while
the ports inherited that design. Those timestamps cannot rank agent productivity.

The journals do record specific friction:

- C: the sandbox initially prevented native window access; boss collision geometry
  needed an explicit core-entry rule. See entries 0004 and 0005.
- Odin: the installed compiler's LLVM 19/20 mismatch broke optimized builds;
  constant-table indexing needed addressable storage; native shutdown required
  cleanup in Sokol's callback. See entries 0011 and 0012. The LLVM mismatch was a
  machine setup issue, not a gameplay-language defect.
- Zig: matching Sokol revisions, version-specific APIs, accepting underscores in
  the standard integer parser, and a plus sign in padded positive score output
  required attention. See entries 0013 and 0014. These were resolved; the parser
  and formatting behaviors were library semantics, not compiler defects.

C has the least recorded language/toolchain friction in this experiment, with
the limitation that this is not a complete issue ledger. My expectation is that
C is easiest for an agent to get compiling against stable C interfaces, Odin can
reduce the amount of application code to maintain, and Zig benefits especially
from consulting the exact installed version's library source. This is an
inference, not a measured generation-speed ranking.
