const std = @import("std");
const game = @import("game.zig");
pub const c = @import("gna");
pub const Handle = c.GnaAudio;

pub fn load(allocator: std.mem.Allocator, root: []const u8) !*Handle {
    // Path strings are borrowed only during create; the C library owns decoded samples.
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const scratch = arena.allocator();
    var sounds: [std.enums.values(game.Sound).len]c.GnaSoundDesc = undefined;
    for (std.enums.values(game.Sound)) |id| {
        sounds[@backingInt(id)] = .{
            .path = (try std.fmt.allocPrintSentinel(scratch, "{s}/audio/{s}.wav", .{ root, @tagName(id) }, 0)).ptr,
            .max_seconds = switch (id) {
                .warning => 0.6,
                .boss_ram => 1.2,
                else => 0,
            },
            .protected_voice = switch (id) {
                .intro_warning, .intro_go => 1,
                else => 0,
            },
        };
    }
    const music = try std.fmt.allocPrintSentinel(scratch, "{s}/audio/music.mp3", .{root}, 0);
    var error_text: [2304]u8 = @splat(0);
    return c.gna_create(&sounds, sounds.len, music.ptr, &error_text, error_text.len) orelse {
        std.log.err("Cannot load audio: {s}", .{std.mem.sliceTo(&error_text, 0)});
        return error.AudioLoadFailed;
    };
}

test "shared C audio is decoded and mixed through the Zig ABI" {
    const a = try load(std.testing.allocator, @import("options").asset_root);
    defer c.gna_destroy(a);
    try std.testing.expect(c.gna_decoded_bytes(a) > 30 * 1024 * 1024);
    c.gna_set_volume(a, 1, 0, 1);
    try std.testing.expect(c.gna_play(a, @backingInt(game.Sound.player_shot), 1) != 0);
    var samples: [2048]f32 = undefined;
    c.gna_mix(a, &samples, samples.len / 2, 48000);
    var audible = false;
    for (samples) |sample| {
        try std.testing.expect(std.math.isFinite(sample) and @abs(sample) <= 1);
        audible = audible or sample != 0;
    }
    try std.testing.expect(audible);
    c.gna_set_paused(a, 1);
    c.gna_mix(a, &samples, samples.len / 2, 48000);
    for (samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
    c.gna_set_paused(a, 0);
    c.gna_stop_effects(a);
    try std.testing.expectEqual(@as(u32, 0), c.gna_active_voices(a));
    _ = c.gna_play(a, @backingInt(game.Sound.intro_warning), 1);
    for (0..30) |_| {
        _ = c.gna_play(a, @backingInt(game.Sound.player_shot), 1);
    }
    try std.testing.expectEqual(@as(u32, c.GNA_VOICE_COUNT), c.gna_active_voices(a));
    c.gna_set_volume(a, 0, 1, 1);
    c.gna_mix(a, &samples, samples.len / 2, 44100);
    for (samples) |sample| try std.testing.expectEqual(@as(f32, 0), sample);
}
