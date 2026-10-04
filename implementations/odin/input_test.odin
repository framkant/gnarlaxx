package gnarlaxx

import "core:testing"
import g "game"
import sapp "../../vendor/sokol_odin/app"

@(test)
keyboard_edges_and_focus_pause :: proc(t: ^testing.T) {
    app = {}
    app_context = context
    g.init(&app.game)
    defer g.destroy(&app.game)
    app.game.scene = .Play
    event(&sapp.Event{type = .KEY_DOWN, key_code = .D})
    event(&sapp.Event{type = .KEY_DOWN, key_code = .SPACE})
    event(&sapp.Event{type = .KEY_DOWN, key_code = .ENTER})
    first := input()
    second := input()
    testing.expect(t, first.x == 1 && first.fire && first.confirm)
    testing.expect(t, second.x == 1 && second.fire && !second.confirm)
    event(&sapp.Event{type = .KEY_DOWN, key_code = .ENTER, key_repeat = true})
    testing.expect(t, !input().confirm)
    event(&sapp.Event{type = .KEY_UP, key_code = .D})
    testing.expect(t, input().x == 0)
    event(&sapp.Event{type = .UNFOCUSED})
    testing.expect(t, app.game.scene == .Pause && !input().fire)
    g.update(&app.game, {confirm = true}, g.GAME_STEP)
    testing.expect(t, app.game.scene == .Play)
    // The diagnostic autopilot is the only focus-pause exception.
    app.demo = true
    event(&sapp.Event{type = .ICONIFIED})
    testing.expect(t, app.game.scene == .Play)
}
