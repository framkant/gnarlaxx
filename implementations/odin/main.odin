package gnarlaxx

import "base:runtime"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:strconv"
import g "game"
import audio "audio"
import renderer "renderer"
import presentation "presentation"
import scores "scores"
import sapp "../../vendor/sokol_odin/app"
import slog "../../vendor/sokol_odin/log"
import stm "../../vendor/sokol_odin/time"

App :: struct {
    game: g.Game,
    audio: ^audio.Handle,
    scores: scores.Scores,
    held, pressed: [sapp.MAX_KEYCODES]bool,
    save_failed, audio_available, demo, mute, failed, owns_score_path: bool,
    accumulator, work_seconds, max_work_seconds: f64,
    started: u64,
    frames, frame_limit: int,
    asset_root, capture, score_path, diagnostic_scene: string,
}

app: App
app_context: runtime.Context
allocation_tracker: mem.Tracking_Allocator
tracking_active: bool

finish_allocations :: proc() {
    if app.owns_score_path {
        delete(app.score_path)
        app.owns_score_path = false
    }
    if tracking_active {
        fmt.printf("Odin allocator: %d live allocations / %d bytes after shutdown\n",
            len(allocation_tracker.allocation_map), allocation_tracker.current_memory_allocated)
        assert(len(allocation_tracker.allocation_map) == 0)
        mem.tracking_allocator_destroy(&allocation_tracker)
        tracking_active = false
    }
}

set_diagnostic_scene :: proc() {
    if app.diagnostic_scene == "" || app.diagnostic_scene == "menu" { return }
    game := &app.game
    g.start(game)
    if app.diagnostic_scene == "briefing" { return }
    game.scene = .Play; game.fade = 0; game.player.pos = {g.GAME_CENTER_X, g.PLAYER_SPAWN_Y}
    if app.diagnostic_scene == "play" { return }
    game.waves_spawned = g.PAWN_WAVE_COUNT; game.drones_spawned = g.DRONE_COUNT
    g.spawn_boss(game); game.boss.pos = {g.GAME_CENTER_X, g.BOSS_REST_Y}; game.boss.phase = .Roam
    switch app.diagnostic_scene {
    case "core": game.boss.left_hp = 0; game.boss.right_hp = 0; game.boss.core_open = true
    case "pause": g.pause(game)
    case "victory": game.scene = .Victory; game.boss.active = false; game.score = 10000
    case "boss":
    case: fmt.eprintf("Unknown --scene: %s\n", app.diagnostic_scene); os.exit(1)
    }
}

init :: proc "c"() {
    context = app_context
    defer free_all(context.temp_allocator)
    stm.setup(); g.init(&app.game)
    if app.score_path == "" {
        home := os.get_env("HOME", context.temp_allocator)
        if home == "" { fmt.eprintln("Cannot locate save directory; use --scores PATH"); os.exit(1) }
        directory := fmt.tprintf("%s/Library/Application Support/Gnarlaxx", home)
        err := os.make_directory(directory, 0o700)
        app.save_failed = err != nil && err != os.EEXIST
        app.score_path = fmt.aprintf("%s/scores.txt", directory)
        app.owns_score_path = true
    }
    app.scores, _ = scores.load(app.score_path)
    if !renderer.init(app.asset_root) { renderer.shutdown(); os.exit(1) }
    app.audio = audio.load(app.asset_root)
    if app.audio == nil { renderer.shutdown(); os.exit(1) }
    app.audio_available = audio.device_open(app.audio) != 0
    if app.mute { app.game.volumes[.Master] = 0 }
    set_diagnostic_scene()
    if app.demo && app.diagnostic_scene == "" { g.start(&app.game) }
    if app.game.allocation_error != .None { fmt.eprintln("Cannot allocate initial game state"); app.failed = true; sapp.request_quit() }
    fmt.printf("Gnarlaxx Odin: Metal; audio=%s (%d Hz); decoded audio=%.2f MiB; game inline state=%d bytes\n",
        "ready" if app.audio_available else "unavailable", audio.device_rate(app.audio), f64(audio.decoded_bytes(app.audio))/1048576, size_of(g.Game))
    app.started = stm.now()
}

held :: proc(key: sapp.Keycode) -> bool { return app.held[int(key)] }
pressed :: proc(key: sapp.Keycode) -> bool { return app.pressed[int(key)] }

input :: proc() -> g.Input {
    result := g.Input{
        x = f32(int(held(.D) || held(.RIGHT))-int(held(.A) || held(.LEFT))),
        y = f32(int(held(.S) || held(.DOWN))-int(held(.W) || held(.UP))),
        fire = held(.SPACE), confirm = pressed(.ENTER), cancel = pressed(.ESCAPE),
        up = pressed(.UP) || pressed(.W), down = pressed(.DOWN) || pressed(.S),
        left = pressed(.LEFT) || pressed(.A), right = pressed(.RIGHT) || pressed(.D),
        sound = pressed(.V), menu = pressed(.Q),
    }
    if app.demo && app.game.scene == .Play {
        target := f32(g.GAME_CENTER_X)+math.sin(app.game.level_time*.9)*125
        b := &app.game.boss
        if b.active { target = b.pos.x if b.core_open else g.boss_gun(b, b.left_hp == 0).x }
        result.x = clamp((target-app.game.player.pos.x)*.03, -1, 1); result.fire = true
        app.game.player.invincible = 1000
    }
    app.pressed = {}
    return result
}

process_events :: proc() {
    for event in app.game.events {
        switch e in event {
        case g.Sound_Event: audio.play(app.audio, e.sound, e.gain)
        case g.Finished_Event:
            fmt.printf("Run finished: %v, score=%d, mission time=%.2fs\n", app.game.scene, e.score, app.game.level_time)
            if !app.demo && app.diagnostic_scene == "" {
                scores.insert(&app.scores, e.score)
                app.save_failed = !scores.save(app.scores, app.score_path)
                if app.save_failed { fmt.eprintf("Could not save scores to %s\n", app.score_path) }
            }
        }
    }
    clear(&app.game.events)
}

frame :: proc "c"() {
    context = app_context
    // UI formatting, file paths and FFI C strings borrow this frame's scratch space.
    // Game collections use context.allocator, which remains live across frames.
    defer free_all(context.temp_allocator)
    begin := stm.now()
    app.accumulator += min(sapp.frame_duration(), .1)
    for app.accumulator >= g.GAME_STEP {
        previous := app.game.scene
        if !g.update(&app.game, input(), g.GAME_STEP) {
            fmt.eprintf("Cannot grow game collections: %v\n", app.game.allocation_error)
            app.failed = true; sapp.request_quit(); break
        }
        if (app.game.scene == .Briefing && previous != .Briefing && previous != .Pause && previous != .Sound) ||
            (app.game.scene == .Menu && previous != .Menu) { audio.stop_effects(app.audio) }
        process_events(); app.accumulator -= g.GAME_STEP
    }
    audio.set_volume(app.audio, app.game.volumes[.Master], app.game.volumes[.Music], app.game.volumes[.Effects])
    audio.set_paused(app.audio, i32(app.game.scene == .Pause))
    if app.audio_available && audio.device_pump(app.audio) == 0 { fmt.eprintln("Audio queue could not accept mixed frames") }
    presentation.draw(&app.game, app.scores, app.save_failed, app.audio_available)
    work := stm.sec(stm.since(begin)); app.work_seconds += work; app.max_work_seconds = max(app.max_work_seconds, work)
    app.frames += 1
    if app.frame_limit > 0 && app.frames >= app.frame_limit {
        if app.capture != "" && !renderer.capture(app.capture) { fmt.eprintf("Capture failed: %s\n", app.capture); app.failed = true }
        sapp.request_quit()
    }
    if app.game.quit_requested { sapp.request_quit() }
}

event :: proc "c"(e: ^sapp.Event) {
    context = app_context
    if e.type == .UNFOCUSED || e.type == .ICONIFIED {
        app.held = {}; app.pressed = {}
        if !app.demo { g.pause(&app.game) }
        return
    }
    key := int(e.key_code)
    if key < 0 || key >= sapp.MAX_KEYCODES { return }
    if e.type == .KEY_DOWN { app.held[key] = true; if !e.key_repeat { app.pressed[key] = true } }
    else if e.type == .KEY_UP { app.held[key] = false }
}

cleanup :: proc "c"() {
    context = app_context
    elapsed := stm.sec(stm.since(app.started))
    fmt.printf("Stats: %d frames / %.2fs = %.1f fps; frame work avg %.3fms max %.3fms\n",
        app.frames, elapsed, f64(app.frames)/elapsed if elapsed>0 else 0,
        app.work_seconds*1000/f64(app.frames) if app.frames>0 else 0, app.max_work_seconds*1000)
    game := &app.game
    fmt.printf("Game storage: %d inline bytes + %d retained heap bytes; capacities: %d enemies, %d bullets, %d explosions, %d events\n",
        size_of(g.Game), g.heap_bytes(game), cap(game.enemies), cap(game.bullets), cap(game.explosions), cap(game.events))
    g.destroy(game)
    audio.destroy(app.audio)
    renderer.shutdown()
    // macOS Sokol may terminate the process instead of returning from sapp.run.
    finish_allocations()
    if app.failed { os.exit(1) }
}

main :: proc() {
    when #config(GNARLAXX_TRACK_MEMORY, false) {
        mem.tracking_allocator_init(&allocation_tracker, context.allocator)
        context.allocator = mem.tracking_allocator(&allocation_tracker)
        tracking_active = true
    }
    defer finish_allocations()
    app_context = context
    app.asset_root = #config(GNARLAXX_ASSET_ROOT,"assets")
    for i := 1; i<len(os.args); i += 1 {
        arg := os.args[i]
        switch arg {
        case "--demo": app.demo = true
        case "--mute": app.mute = true
        case "--frames","--capture","--assets","--scores","--scene":
            i += 1
            if i >= len(os.args) { fmt.eprintf("Missing value for %s\n", arg); os.exit(1) }
            value := os.args[i]
            switch arg {
            case "--frames":
                ok: bool; n: int
                app.frame_limit, ok = strconv.parse_int(value, 10, &n)
                if !ok || n != len(value) || app.frame_limit <= 0 { fmt.eprintln("--frames requires a positive integer"); os.exit(1) }
            case "--capture": app.capture = value
            case "--assets": app.asset_root = value
            case "--scores": app.score_path = value
            case "--scene": app.diagnostic_scene = value
            }
        case "--help":
            fmt.println("Gnarlaxx Odin: WASD/arrows move, Space fires, Enter selects, Esc pauses, V sound, Q leaves paused run.\nOptions: --assets PATH --scores PATH --mute\nDiagnostics: --frames N --capture PNG --demo (invulnerable, no saves)\n             --scene menu|briefing|play|boss|core|pause|victory (no saves)")
            return
        case: fmt.eprintf("Unknown option: %s\n", arg); os.exit(1)
        }
    }
    if app.capture != "" && app.frame_limit == 0 { fmt.eprintln("--capture requires --frames"); os.exit(1) }
    sapp.run({init_cb = init, frame_cb = frame, event_cb = event, cleanup_cb = cleanup,
        width = g.GAME_WIDTH*g.WINDOW_SCALE, height = g.GAME_HEIGHT*g.WINDOW_SCALE,
        window_title = "Gnarlaxx - Odin", high_dpi = true, sample_count = 1, icon = {sokol_default = true}, logger = {func = slog.func}})
    if app.failed { os.exit(1) }
}
