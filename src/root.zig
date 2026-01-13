pub const std: type = @import("std");
pub const rl: type = @import("raylib");
pub const rgui: type = @import("raygui");

pub const InputTag = enum { mouse, keyboard, gamepad };
pub const Input = union(InputTag) {
	pub const State = enum { up, down, pressed, released };
	mouse: rl.MouseButton,
	keyboard: rl.KeyboardKey,
	gamepad: struct {button: rl.GamepadButton, id: i32},
	pub fn is(self: Input, state: State) bool { return switch (state) {
		.up => !self.is(.down),
		.down => switch (self) {
			.mouse => |mb| rl.isMouseButtonDown(mb),
			.keyboard => |k| rl.isKeyDown(k),
			.gamepad => |gp| rl.isGamepadButtonDown(gp.id, gp.button),
		},
		.pressed => switch (self) {
			.mouse => |mb| rl.isMouseButtonPressed(mb),
			.keyboard => |k| rl.isKeyPressed(k),
			.gamepad => |gp| rl.isGamepadButtonPressed(gp.id, gp.button),
		},
		.released => switch (self) {
			.mouse => |mb| rl.isMouseButtonReleased(mb),
			.keyboard => |k| rl.isKeyReleased(k),
			.gamepad => |gp| rl.isGamepadButtonReleased(gp.id, gp.button),
		},
	};}
};

pub const Player = struct {
	x: f32, y: f32,
	vel: rl.Vector2,
	size: rl.Vector2,

	pub fn shifted(self: *const @This(), v: rl.Vector2) @This() {
		return .{
			.size = self.size,
			.vel = self.vel,
			.x = self.x + v.x,
			.y = self.y + v.y,
		};
	}

	pub fn rectangle(self: *const @This()) rl.Rectangle { return .{
		.x = self.x,
		.y = self.y,
		.width = self.size.x,
		.height = self.size.y,
	};}

	pub fn pos(self: *@This()) rl.Vector2 { return .{.x = self.x, .y = self.y}; }
};

pub fn EnumMap(EnumKey: type, Value: type) type { return struct {
    pub const count = @typeInfo(EnumKey).@"enum".fields.len;
    const Self = @This();
    pub const Pair = struct {EnumKey, Value};
    values: [count]Value,
    pub fn new(pairs: *const [count]Pair) Self {
        var self: Self = undefined;
        inline for (pairs) |pair| {
            const key, const value = pair;
            self.values[@intFromEnum(key)] = value;
        }
        return self;
    }
    pub fn at(self: *Self, key: EnumKey) Value {
        return self.values[@intFromEnum(key)];
    }
    pub fn @"&"(self: *Self, key: EnumKey) *Value {
        return &self.values[@intFromEnum(key)];
    }
};}

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

pub fn screenV() rl.Vector2 { return .{
	.x = @floatFromInt(rl.getScreenWidth()),
	.y = @floatFromInt(rl.getScreenHeight()),
};}

/// Draws a vector with specified thickness and `color` in the center of
/// the screen. Should be called outside of a `Mode2D` context.
pub fn drawVecCentered(thick: f32, color: rl.Color, vec: rl.Vector2) void {
    const origin = screenV().scale(0.5);
	rl.drawLineEx(origin, origin.add(vec), thick, color);
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
