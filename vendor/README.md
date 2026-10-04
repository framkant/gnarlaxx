# Vendored dependencies

Only the sources used by this project are included. Upstream licenses are
retained, and builds need no network access. Headers are unmodified; the Odin
bindings have the library-linking adjustment described below.

| Library | Revision | Use | License |
| --- | --- | --- | --- |
| [Sokol](https://github.com/floooh/sokol) | `2e75443dbd4940b5aa8d76a8e479f8e4b270b9a3` | Window/input, Metal graphics, immediate-mode sprite drawing, audio output, timing/logging | [zlib](sokol/LICENSE) |
| [dr_libs](https://github.com/mackron/dr_libs) | `dfe8377631000664666519fdb83da193fd8037f4` | WAV and MP3 decoding | [Choice of MIT-0 or public domain](dr_libs/LICENSE) |
| [stb](https://github.com/nothings/stb) | `2c980bb59875b0d32144a71867fbdebb2f77cd20` | PNG decoding | [Choice of MIT or public domain](stb/LICENSE) |
| [sokol-odin](https://github.com/floooh/sokol-odin) | `132fa9d26acf98cf6358a61e8baadf985196ab42` | Odin app, gfx, gl, glue, log and time bindings | [zlib](sokol_odin/LICENSE) |

`checksums.json` records every vendored source/license file. The original
licenses apply to these files, independently of the root project license.

The selected sokol-odin revision embeds headers byte-identical to our pinned
Sokol headers. Its six binding files retain upstream declarations but replace
the platform-specific prebuilt-library selection with `GNARLAXX_SOKOL_LIB` and
the macOS frameworks. This links the same locally compiled platform glue as C,
with `SOKOL_NO_ENTRY` because Odin supplies `main`. No upstream prebuilt binaries
are included. Zig bindings will likewise need matching headers.

Audio currently uses Sokol's push interface plus a small C mixer. Miniaudio is
unnecessary for the first version. All assets are decoded once at startup, a
deliberate simplicity/memory tradeoff that will be measured and compared later.
