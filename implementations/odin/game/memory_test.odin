package game
import "core:mem"
import "core:testing"
import "core:fmt"

// Move every growth allocation so stale element pointers cannot accidentally work.
// Fail each successive allocation in the same stress workload as separate runs.
Fault_Allocator :: struct { backing: mem.Allocator, calls, fail_at: int }
fault_proc :: proc(data: rawptr, mode: mem.Allocator_Mode, size, alignment: int,
    old: rawptr, old_size: int, loc := #caller_location) -> ([]u8, mem.Allocator_Error) {
    state := cast(^Fault_Allocator)data
    if mode == .Alloc || mode == .Alloc_Non_Zeroed || mode == .Resize || mode == .Resize_Non_Zeroed {
        state.calls += 1
        if state.calls == state.fail_at { return nil, .Out_Of_Memory }
        allocated, err := state.backing.procedure(state.backing.data, .Alloc, size, alignment, nil, 0, loc)
        if err != .None { return nil, err }
        if old != nil {
            copy(allocated, (cast([^]u8)old)[: min(old_size, size)])
            state.backing.procedure(state.backing.data, .Free, 0, alignment, old, old_size, loc)
        }
        return allocated, .None
    }
    return state.backing.procedure(state.backing.data, mode, size, alignment, old, old_size, loc)
}

stress :: proc(g: ^Game) -> bool {
    if !start(g) { return false }
    for i in 0..<2000 {
        if !push(g, &g.enemies, Enemy{active = i%2 == 0, pos = {f32(i), 0}}) { return false }
        if !push(g, &g.bullets, Bullet{active = i%2 == 0, pos = {f32(i), 0}}) { return false }
        if !push(g, &g.explosions, Explosion{active = i%2 == 0, pos = {f32(i), 0}}) { return false }
        sound(g, .Player_Shot, 1)
        if g.allocation_error != .None { return false }
    }
    return true
}
@(test)
growth_compaction_and_failure_cleanup :: proc(t: ^testing.T) {
    successful_calls := 0
    for attempt := 0; attempt <= successful_calls; attempt += 1 {
        tracker: mem.Tracking_Allocator
        mem.tracking_allocator_init(&tracker, context.allocator)
        state := Fault_Allocator{backing = mem.tracking_allocator(&tracker), fail_at = attempt}
        g: Game; init(&g, mem.Allocator{procedure = fault_proc, data = &state})
        ok := stress(&g)
        if attempt == 0 {
            testing.expect(t, ok)
            successful_calls = state.calls
            fmt.printf("Odin allocation stress: %d forced moves; testing every failure position\n", successful_calls)
            compact(&g.enemies); compact(&g.bullets); compact(&g.explosions)
            testing.expect(t, len(g.enemies) == 1000 && len(g.bullets) == 1000 && len(g.explosions) == 1000)
            for e, i in g.enemies { testing.expect(t, e.pos.x == f32(i*2)) }
            for b, i in g.bullets { testing.expect(t, b.pos.x == f32(i*2)) }
            for e, i in g.explosions { testing.expect(t, e.pos.x == f32(i*2)) }
            bytes := heap_bytes(&g)
            testing.expect(t, start(&g) && heap_bytes(&g) == bytes && state.calls == successful_calls)
            testing.expect(t, len(g.enemies) == 0 && len(g.bullets) == 0 && len(g.explosions) == 0 && len(g.events) == 1)
        } else {
            testing.expect(t, !ok && g.allocation_error == .Out_Of_Memory)
            calls := state.calls
            testing.expect(t, !update(&g, {fire = true}, GAME_STEP) && !start(&g) && state.calls == calls)
        }
        destroy(&g); destroy(&g)
        testing.expect(t, len(tracker.allocation_map) == 0 && tracker.current_memory_allocated == 0)
        mem.tracking_allocator_destroy(&tracker)
    }
}
