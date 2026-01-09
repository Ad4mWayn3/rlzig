const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");
const rmath = rl.math;
const allocator = std.heap.page_allocator;

const res = .{ .w = 1920, .h = 1080 };

const Game: type = struct {
	map: std.ArrayList(rl.Rectangle),
	boxTip: rl.Vector2,
	boxTail: rl.Vector2,
	selectorTip: rl.Vector2,
	selectorTail: rl.Vector2,
	selected: std.DynamicBitSetUnmanaged,
	camera: rl.Camera2D,
	mode: enum { scroll, build, edit,
		fn name(self: @This()) []const u8 {
			return switch (self) {
			.scroll => "scroll",
			.build => "build",
			.edit => "edit",
			};
		}},
	const Seconds = f32;
	const Self = @This();
	const kInputs = [_]rl.KeyboardKey{ .e, .s, .d, .f };

	fn init(self: *Self, gpa: std.mem.Allocator) !void {
		self.map = try .initCapacity(gpa, 0x40);
		self.selected = try .initEmpty(gpa, 0x40);
		self.mode = .scroll;
		self.camera = .{ 
			.offset = .{ .x = 0, .y = 0 },
			.rotation = 0,
			.target = .{ .x = 0, .y = 0 },
			.zoom = 1
		};
		try loadRectsFromFile("map.bin", gpa, &self.map);
	}

	fn deinit(self: *Self, gpa: std.mem.Allocator) void {
		self.map.deinit(gpa);
		self.selected.deinit(gpa);
	}

	fn update(self: *Self, gpa: std.mem.Allocator, delta: Seconds) !void {
		// const mousePos: rl.Vector2 =
		// rl.getMousePosition().add(self.camera.target);

		//inline for (kInputs) |kInput|
			//if (rl.isKeyDown(kInput)) self.handleInput(kInput, delta);
		_ = delta;
		if (rl.isMouseButtonDown(.right)) {
			self.camera.target = self.camera.target.subtract(rl.getMouseDelta());
		}
		if (self.mode == .build) {
			try self.handleBuildInput(gpa);
		}

		if (self.mode == .edit) {
			try self.handleEditInput(gpa);
		}

		if (rgui.button(.{.x=40, .y=40, .width=200, .height=60}, "build")) {
			self.mode = .build;
		} if (rgui.button(.{.x=40, .y=120, .width=200, .height=60}, "edit")) {
			self.mode = .edit;
		} //if (rgui.textInputBox(.{.x=40, .y=200, .width=400, .height=60}, "input text",

	}

	fn draw(self: *Self) !void {
		var buffer = [_]u8{0} ** 0x200;
		{
			const s1 = try std.fmt.bufPrint(&buffer, "mode: {s}",
				.{self.mode.name()});
			buffer[s1.len] = 0;
			const s2 = buffer[0..s1.len :0];
			rl.drawText(s2, 200,200, 21, .white);
		}
		if (self.mode == .edit) {
			const s2 = \\translate: Z
			\\select: left click
			;
			rl.drawText(s2, 200,260, 21, .white);
		}
		rl.beginMode2D(self.camera);
		for (self.map.items) |rec| {
			rl.drawRectangleRec(rec, .blue);
		}
		// the outlines are drawn in a separate loop to ensure they're on top
		// of every solid rectangle
		for (self.map.items, 0..) |rec, i| {
			if (self.selected.isSet(i))
				rl.drawRectangleLinesEx(rec, 3.0, .white);
		}

		rl.drawRectangleLinesEx(rectangleTipTail(self.selectorTip,
			self.selectorTail), 3.0, .white);
		rl.drawRectangleRec(rectangleTipTail(self.boxTail,
			self.boxTip), .blue);
		rl.endMode2D();
	}

	inline fn handleBuildInput(self: *Self, gpa: std.mem.Allocator) !void {
		const mousePos: rl.Vector2 =
			rl.getMousePosition().add(self.camera.target);

		if (rl.isMouseButtonPressed(.left)) {
			self.boxTip = mousePos;
			self.boxTail = mousePos;
		} else if (rl.isMouseButtonDown(.left)) {
			self.boxTail = mousePos;
		} else if (rl.isMouseButtonReleased(.left)
			and self.boxTail.equals(self.boxTip)==0) {
			try self.map.append(gpa,
				rectangleTipTail(self.boxTip, self.boxTail));
			try self.selected.resize(gpa, self.map.items.len, false);
		} else {
			self.boxTip = self.boxTail;
		}
	}

	inline fn handleEditInput(self: *Self, gpa: std.mem.Allocator) !void {
		const mousePos: rl.Vector2 =
			rl.getMousePosition().add(self.camera.target);
		const mouseDelta = rl.getMouseDelta();

		if (rl.isMouseButtonPressed(.left)) l1: {
			if (rl.isKeyDown(.z)) break :l1;
			self.selectorTip = mousePos;
			self.selectorTail = mousePos;
			if (!rl.isKeyDown(.left_shift))
				self.selected.unsetAll();
			for (self.map.items, 0..) |rec, i| {
				if (isInRectangle(rec, mousePos)) {
					self.selected.toggle(i);
					break;
				}
			}
		} else if (rl.isMouseButtonDown(.left) and !rl.isKeyDown(.z)) l1: {
			self.selectorTail = mousePos;
			if (mouseDelta.lengthSqr() == 0.0) break :l1;
			for (self.map.items, 0..) |rec, i| {
				if (rl.checkCollisionRecs(rectangleTipTail(self.selectorTip,
					self.selectorTail), rec)) {
					self.selected.set(i);
				} else if (!rl.isKeyDown(.left_shift))
					self.selected.unset(i);
			}
		} else {
			self.selectorTail = self.selectorTip;
		}

		const selCount: usize = self.selected.bit_length;
		if (rl.isKeyPressed(.delete)) {
			var indexes = try std.ArrayList(usize).initCapacity(gpa,
				self.map.items.len);
			defer indexes.deinit(gpa);
			for (0..selCount) |i| if (self.selected.isSet(i)) {
				try indexes.append(gpa, i);
				self.selected.unset(i);
			};
			self.map.orderedRemoveMany(indexes.items);
		} else if (rl.isKeyDown(.z)) {for (0..selCount) |i| l: {
			if (!self.selected.isSet(i)) break :l;
			self.map.items[i].x += mouseDelta.x;
			self.map.items[i].y += mouseDelta.y;
		}} else if (rl.isKeyPressed(.c)) {for (0..selCount) |i| {
			_ = i;
		}}
	}
};

pub fn main() !void {
	var game: Game = undefined;
	try game.init(allocator);
	defer game.deinit(allocator);
	rl.setTraceLogLevel(.warning);
	rl.setExitKey(.null);
	rl.setTargetFPS(60);
	rl.initWindow(res.w, res.h, "rlzig!");
	rgui.setStyle(.default, .{ .default = .text_size }, 25);
	defer rl.closeWindow();
	while (!rl.windowShouldClose()) {
		try game.update(allocator, rl.getFrameTime());
		rl.clearBackground(.black);
		rl.beginDrawing();
		try game.draw();
		rl.endDrawing();
	}
}

inline fn isInRectangle(rec: rl.Rectangle, v: rl.Vector2) bool {
	return v.x >= rec.x and v.x <= rec.x + rec.width
		and v.y >= rec.y and v.y <= rec.y + rec.height;
}

fn rectangleV(v: rl.Vector2, u: rl.Vector2) rl.Rectangle {
	return rl.Rectangle { 
		.x		= v.x, 	.y 		= v.y,
		.width	= u.x,	.height = u.y,
	};
}

fn rectangleTipTail(v: rl.Vector2, u: rl.Vector2
) rl.Rectangle { return rl.Rectangle {
	.x = @min(v.x, u.x),
	.y = @min(v.y, u.y),
	.width = @abs(u.x - v.x),
	.height = @abs(u.y - v.y)
};}

fn saveRectsToFile(path: []const u8, recs: []rl.Rectangle) !void {
	const file = try std.fs.cwd().createFile(path, .{});
	defer file.close();
	const stride: usize = @sizeOf([4]f32);
	comptime std.debug.assert(@sizeOf(rl.Rectangle) == stride);
	for (recs) |rec| {
		const a: [stride]u8 = @bitCast(rec);
		_ = try file.write(&a);
	}
}

fn loadRectsFromFile(path: []const u8, gpa: std.mem.Allocator,
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
