pub const std: type = @import("std");
pub const rl: type = @import("raylib");
pub const rgui: type = @import("raygui");

pub inline fn isInRectangle(rec: rl.Rectangle, v: rl.Vector2) bool {
    return v.x >= rec.x and v.x <= rec.x + rec.width and v.y >= rec.y and v.y <= rec.y + rec.height;
}

pub inline fn rectangleV(v: rl.Vector2, u: rl.Vector2) rl.Rectangle {
    return rl.Rectangle{
        .x = v.x,
        .y = v.y,
        .width = u.x,
        .height = u.y,
    };
}

pub inline fn rectangleTipTail(v: rl.Vector2, u: rl.Vector2) rl.Rectangle {
    return rl.Rectangle{ .x = @min(v.x, u.x), .y = @min(v.y, u.y), .width = @abs(u.x - v.x), .height = @abs(u.y - v.y) };
}

pub fn translate(comptime T: type, v: rl.Vector2, x: T) T {
    var x_new = x;
    x_new.x += v.x;
    x_new.y += v.y;
    return x_new;
}

pub fn saveRectsToFile(path: []const u8, recs: []rl.Rectangle) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    const stride: usize = @sizeOf([4]f32);
    comptime std.debug.assert(@sizeOf(rl.Rectangle) == stride);
    for (recs) |rec| {
        const a: [stride]u8 = @bitCast(rec);
        _ = try file.write(&a);
    }
}

pub fn loadRectsFromFile(path: []const u8, gpa: std.mem.Allocator,
    recs: *std.ArrayList(rl.Rectangle)
) !void {
    const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });
    defer file.close();
    const stride: usize = @sizeOf([4]f32);
    comptime std.debug.assert(@sizeOf(rl.Rectangle) == stride);

    const eof: usize = try file.getEndPos();
    var recb: [stride]u8 = undefined;
    if (eof < stride) return;
    var i: usize = 0;
    while (i < eof) : (i += stride) {
        _ = try file.read(&recb);
        try recs.append(gpa, @bitCast(recb));
        try file.seekTo(i);
    }
}
