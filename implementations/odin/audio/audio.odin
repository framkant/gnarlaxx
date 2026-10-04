package audio

import "core:fmt"
import game "../game"

// This is the complete shared C ABI; no game or presentation code crosses it.
Handle :: struct {}
Sound_Desc :: struct {
    path: cstring,
    max_seconds: f64,
    protected_voice: i32,
}
#assert(size_of(Sound_Desc) == 24)
#assert(offset_of(Sound_Desc, max_seconds) == 8)
#assert(offset_of(Sound_Desc, protected_voice) == 16)
CLIB :: #config(GNARLAXX_AUDIO_LIB,  "../../../build/odin/native/libs/audio/libgnarlaxx_audio.a")
foreign import library {CLIB,  "system:AudioToolbox.framework"}
@(default_calling_convention = "c", link_prefix = "gna_")
foreign library {
    create :: proc(sounds: [^]Sound_Desc, count: u32, music: cstring, error: [^]u8, capacity: uintptr) -> ^Handle ---
    destroy :: proc(audio: ^Handle) ---
    set_volume :: proc(audio: ^Handle, master, music, effects: f32) ---
    set_paused :: proc(audio: ^Handle, paused: i32) ---
    play :: proc(audio: ^Handle, sound: game.Sound, gain: f32) -> i32 ---
    stop_effects :: proc(audio: ^Handle) ---
    decoded_bytes :: proc(audio: ^Handle) -> u64 ---
    active_voices :: proc(audio: ^Handle) -> u32 ---
    mix :: proc(audio: ^Handle, stereo: [^]f32, frames, rate: u32) ---
    device_open :: proc(audio: ^Handle) -> i32 ---
    device_close :: proc(audio: ^Handle) ---
    device_pump :: proc(audio: ^Handle) -> i32 ---
    device_rate :: proc(audio: ^Handle) -> u32 ---
}

load :: proc(root: string) -> ^Handle {
    files := [game.Sound]string{
        .Player_Shot = "player_shot", .Enemy_Shot = "enemy_shot", .Hit = "hit",
        .Explosion = "explosion", .Boss_Explosion = "boss_explosion", .Warning = "warning",
        .Menu_Confirm = "menu_confirm", .Boss_Ram = "boss_ram",
        .Intro_Warning = "intro_warning", .Intro_Go = "intro_go",
    }
    sounds: [game.Sound]Sound_Desc
    // create copies/decodes all borrowed paths before returning.
    for file, id in files { sounds[id].path = fmt.ctprintf("%s/audio/%s.wav", root, file) }
    sounds[.Warning].max_seconds = .6
    sounds[.Boss_Ram].max_seconds = 1.2
    sounds[.Intro_Warning].protected_voice = 1
    sounds[.Intro_Go].protected_voice = 1
    error: [2304]u8
    result := create(cast([^]Sound_Desc)&sounds, u32(len(sounds)), fmt.ctprintf("%s/audio/music.mp3", root), raw_data(error[: ]), len(error))
    if result == nil { fmt.eprintf("Cannot load audio: %s\n", cstring(raw_data(error[: ]))) }
    return result
}
