# Vendored dependencies

Only the headers used by this project are included. The files are unmodified,
their upstream licenses are retained, and builds need no network access.

| Library | Revision | Use | License |
| --- | --- | --- | --- |
| [Sokol](https://github.com/floooh/sokol) | `2e75443dbd4940b5aa8d76a8e479f8e4b270b9a3` | Window/input, Metal graphics, immediate-mode sprite drawing, audio output, timing/logging | [zlib](sokol/LICENSE) |
| [dr_libs](https://github.com/mackron/dr_libs) | `dfe8377631000664666519fdb83da193fd8037f4` | WAV and MP3 decoding | [Choice of MIT-0 or public domain](dr_libs/LICENSE) |
| [stb](https://github.com/nothings/stb) | `2c980bb59875b0d32144a71867fbdebb2f77cd20` | PNG decoding | [Choice of MIT or public domain](stb/LICENSE) |

`checksums.json` records every vendored source/license file. The original
licenses apply to these files, independently of the root project license.

Sokol has official [Odin](https://github.com/floooh/sokol-odin) and
[Zig](https://github.com/floooh/sokol-zig) bindings covering the selected modules.
Their examples include offscreen rendering, sokol-gl, and audio. This confirms
the shared approach is available; compiling the actual ports remains a later
milestone. Bindings and their embedded C headers must use matching API revisions
when those ports are built.

Audio currently uses Sokol's push interface plus a small C mixer. Miniaudio is
unnecessary for the first version. All assets are decoded once at startup, a
deliberate simplicity/memory tradeoff that will be measured and compared later.
