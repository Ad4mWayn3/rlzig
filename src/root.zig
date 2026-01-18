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
    orientation: enum {horizontal, vertical},

	pub fn shifted(self: *const @This(), v: rl.Vector2) @This() {
		return .{
			.size = self.size,
			.vel = self.vel,
			.x = self.x + v.x,
			.y = self.y + v.y,
            .orientation = self.orientation,
		};
	}

	pub fn rectangle(self: *const @This()) rl.Rectangle {
        var x, var y, var w, var h = .{self.x, self.y,
            self.size.x, self.size.y};
        if (self.orientation == .horizontal) {
            x, y = .{x - (h-w)/2.0, y + (h-w)/2.0};
            std.mem.swap(f32, &w, &h);
        }
        return .{
            .x = x,
            .y = y,
            .width = w,
            .height = h,
        };
    }

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

/// returns the upper left, upper right, lower left and lower right points of
/// `rec` respectively.
pub fn recPoints(rec: rl.Rectangle) [4]rl.Vector2 {
    const x, const y, const w, const h = .{rec.x, rec.y, rec.width, rec.height};
    return .{.{.x=x,.y=y},.{.x=x+w,.y=y},.{.x=x,.y=y+h},.{.x=x+w,.y=y+h}};
}

/// Amount of intersection between two intervals. Negative if none. Asserts
/// that the lower bound is strictly smaller than the upper bound for both
/// intervals.
pub fn intersection(Num: type,
    x: struct{Num,Num},
    y: struct{Num,Num},
) f32 {
    std.debug.assert(x[0] < x[1] and y[0] < y[1]);
    return @min(x[1],y[1]) - @max(x[0],y[0]);
}

pub fn collisionDepthAxis(xs: []rl.Vector2, ys: []rl.Vector2,
    axis: rl.Vector2
) f32 {
    const dot = .{xs[0].dotProduct(axis), ys[0].dotProduct(axis)};
    var x = .{.min = dot[0], .max = dot[0]};
    var y = .{.min = dot[1], .max = dot[1]};
    for (0..@max(xs.len,ys.len)) |i| {
        if (i<xs.len) {
            if (xs[i] < x.min) x.min = xs[i]
            else if (xs[i] > x.max) x.max = xs[i];
        }
        if (i<ys.len) {
            if (ys[i] < y.min) y.min = ys[i]
            else if (ys[i] > y.max) y.max = ys[i];
        }
    }
    return intersection(f32,.{x.min,x.max},.{y.min,y.max});
}

/// Finds the axis with least collision depth in `axes`, stores it to `minAxis`
/// and returns the depth. Negative depth means the stored `minAxis` is a
/// separating axis, and the polygons aren't colliding. May not be sufficient
/// for accurate collision checking if not enough `axes` are provided or either
/// `xs` or `ys` are non-convex.
pub fn minCollisionDepthAxes(xs: []rl.Vector2, ys: []rl.Vector2,
    axes: []rl.Vector2, minAxis: *rl.Vector2
) f32 {
    std.debug.assert(xs.len*ys.len*axes.len != 0); // no empty arrays
    var minDepth = std.math.floatMax(f32);
    for (axes) |axis| {
        std.debug.assert(@abs(axis.length()-1.0) < 1e-5);
        const depth = collisionDepthAxis(xs, ys, axis);
        if (depth < minDepth) {
            minDepth = depth;
            minAxis.* = axis;
        }
        if (depth < 0.0)
            return depth;
    }
    return minDepth;
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
