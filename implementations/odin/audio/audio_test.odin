package audio
import "core:testing"
import "core:math"

@(test)
shared_library_from_odin :: proc(t: ^testing.T) {
    defer free_all(context.temp_allocator)
    a := load(#config(GNARLAXX_ASSET_ROOT,"assets"))
    assert(a != nil); defer destroy(a)
    testing.expect(t, decoded_bytes(a)>30*1024*1024)
    samples: [2048]f32
    set_volume(a, 1, 0, 1)
    testing.expect(t, play(a, .Player_Shot, 1) != 0 && active_voices(a) == 1)
    mix(a, raw_data(samples[: ]), u32(len(samples)/2), 48000)
    audible := false
    for sample in samples { testing.expect(t, !math.is_nan(sample) && abs(sample) <= 1); audible = audible || sample != 0 }
    testing.expect(t, audible)
    set_paused(a, 1); mix(a, raw_data(samples[: ]), u32(len(samples)/2), 48000)
    for sample in samples { testing.expect(t, sample == 0) }
    set_paused(a, 0); stop_effects(a); testing.expect(t, active_voices(a) == 0)
    testing.expect(t, play(a, .Intro_Warning, 1) != 0)
    for _ in 0..<30 { play(a, .Player_Shot, 1) }
    testing.expect(t, active_voices(a) == 24)
    set_volume(a, 0, 1, 1); mix(a, raw_data(samples[: ]), u32(len(samples)/2), 44100)
    for sample in samples { testing.expect(t, sample == 0) }
}
