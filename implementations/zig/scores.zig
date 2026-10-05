const std = @import("std");
const Io = std.Io;
pub const count = 5;
pub const max_score = 999999999;
const header = "GNARLAXX 1\n";
pub const Scores = struct {
    values: [count]i32 = @splat(0),
    pub fn parse(data: []const u8) !Scores {
        if (!std.mem.startsWith(u8, data, header)) return error.InvalidScores;
        var lines = std.mem.splitScalar(u8, data[header.len..], '\n');
        var result: Scores = .{};
        for (&result.values, 0..) |*score, i| {
            const line = std.mem.trim(u8, lines.next() orelse return error.InvalidScores, " \t\r\x0b\x0c");
            // parseInt accepts Zig's underscore separators; the shared file format doesn't.
            if (std.mem.indexOfScalar(u8, line, '_') != null) return error.InvalidScores;
            score.* = std.fmt.parseInt(i32, line, 10) catch return error.InvalidScores;
            if (score.* < 0 or score.* > max_score or (i > 0 and score.* > result.values[i - 1])) return error.InvalidScores;
        }
        if (std.mem.trim(u8, lines.rest(), " \t\r\n\x0b\x0c").len != 0) return error.InvalidScores;
        return result;
    }
    pub fn load(io: Io, allocator: std.mem.Allocator, path: []const u8) !Scores {
        const data = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4096));
        defer allocator.free(data);
        return parse(data);
    }
    pub fn insert(scores: *Scores, score: i32) void {
        if (score < 1 or score > max_score) return;
        for (scores.values, 0..) |value, i| {
            if (score > value) {
                std.mem.copyBackwards(i32, scores.values[i + 1 ..], scores.values[i .. count - 1]);
                scores.values[i] = score;
                return;
            }
        }
    }
    pub fn save(scores: Scores, io: Io, allocator: std.mem.Allocator, path: []const u8) !void {
        const tmp = try std.fmt.allocPrint(allocator, "{s}.tmp", .{path});
        defer allocator.free(tmp);
        errdefer Io.Dir.cwd().deleteFile(io, tmp) catch {};
        var data: [header.len + count * 11]u8 = undefined;
        @memcpy(data[0..header.len], header);
        var written: usize = header.len;
        for (scores.values) |score| written += (try std.fmt.bufPrint(data[written..], "{d}\n", .{score})).len;
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = tmp, .data = data[0..written] });
        try Io.Dir.cwd().rename(tmp, .cwd(), path, io);
    }
};

test "shared score format, ordering, malformed input and atomic replacement" {
    var s = try Scores.parse("GNARLAXX 1\n9000\n500\n0\n0\n0\n \t\n");
    s.insert(700);
    s.insert(0);
    s.insert(max_score + 1);
    try std.testing.expectEqual([5]i32{ 9000, 700, 500, 0, 0 }, s.values);
    try std.testing.expectError(error.InvalidScores, Scores.parse("GNARLAXX 1\n9_000\n0\n0\n0\n0\n"));
    for ([_][]const u8{ "", "GNARLAXX 2\n1\n0\n0\n0\n0\n", "GNARLAXX 1\n1\n2\n0\n0\n0\n", "GNARLAXX 1\n1x\n0\n0\n0\n0\n", "GNARLAXX 1\n-1\n0\n0\n0\n0\n", "GNARLAXX 1\n1000000000\n0\n0\n0\n0\n", "GNARLAXX 1\n1\n0\n0\n0\n", "GNARLAXX 1\n1\n0\n0\n0\n0\nextra" }) |bad| try std.testing.expectError(error.InvalidScores, Scores.parse(bad));
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realPathFileAlloc(std.testing.io, ".", std.testing.allocator);
    defer std.testing.allocator.free(path);
    const file = try std.fmt.allocPrint(std.testing.allocator, "{s}/scores.txt", .{path});
    defer std.testing.allocator.free(file);
    try s.save(std.testing.io, std.testing.allocator, file);
    try std.testing.expectEqual(s.values, (try Scores.load(std.testing.io, std.testing.allocator, file)).values);
    const bytes = try Io.Dir.cwd().readFileAlloc(std.testing.io, file, std.testing.allocator, .limited(4096));
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("GNARLAXX 1\n9000\n700\n500\n0\n0\n", bytes);
    s.insert(9999);
    try s.save(std.testing.io, std.testing.allocator, file);
    try std.testing.expectEqual(s.values, (try Scores.load(std.testing.io, std.testing.allocator, file)).values);
    const bad_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/missing/scores.txt", .{path});
    defer std.testing.allocator.free(bad_path);
    try std.testing.expectError(error.FileNotFound, s.save(std.testing.io, std.testing.allocator, bad_path));
    try std.testing.expectEqual(s.values, (try Scores.load(std.testing.io, std.testing.allocator, file)).values);
}
