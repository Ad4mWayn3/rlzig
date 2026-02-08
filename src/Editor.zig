const root: type = @import("rlzig");
const Player = root.Player;
const std: type = root.std;
const rl: type = root.rl;
const rgui = root.rgui;

const Seconds = f32;
const Self = @This();
const kInputs = [_]rl.KeyboardKey{ .e, .s, .d, .f };

map: std.ArrayList(rl.Rectangle),
boxTip: rl.Vector2,
boxTail: rl.Vector2,
selectorTip: rl.Vector2,
selectorTail: rl.Vector2,
selected: std.DynamicBitSetUnmanaged,
camera: rl.Camera2D,
mode: enum {
	scroll,
	build,
	edit,
	fn name(self: @This()) []const u8 { return switch (self) {
		.scroll => "scroll",
		.build => "build",
		.edit => "edit",
	};}
},

pub fn init(self: *Self, gpa: std.mem.Allocator) !void {
	self.map = try .initCapacity(gpa, 0x40);
	self.selected = try .initEmpty(gpa, 0x40);
	self.mode = .scroll;
	self.camera = .{ .offset = .{ .x = 0, .y = 0 }, .rotation = 0, .target = .{ .x = 0, .y = 0 }, .zoom = 1 };
	try root.loadRectsFromFile("map.bin", gpa, &self.map);
	try self.selected.resize(gpa, self.map.items.len, false);
}

pub fn deinit(self: *Self, gpa: std.mem.Allocator) void {
	self.map.deinit(gpa);
	self.selected.deinit(gpa);
}

pub fn update(self: *Self, gpa: std.mem.Allocator, delta: Seconds) !void {
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

	if (rgui.button(.{ .x = 40, .y = 40, .width = 200, .height = 60 },
	"build")) {
		self.mode = .build;
	}
	if (rgui.button(.{ .x = 40, .y = 40 + 80, .width = 200,
	.height = 60 }, "edit")) {
		self.mode = .edit;
	}
	if (rgui.button(.{ .x = 40, .y = 40 + 80*2,
	.width = 200, .height = 60 }, "save"))
		try root.saveRectsToFile("map.bin", self.map.items);
	
	if (rgui.button(.{ .x = 40, .y = 40 + 80*3, .width = 200,
	.height = 60 }, "load")) {
		self.map.shrinkAndFree(gpa, 0);
		try root.loadRectsFromFile("map.bin", gpa, &self.map);
		self.selected.unsetAll();
		try self.selected.resize(gpa, self.map.items.len, false);
	}
}

pub fn draw(self: *Self, player: *Player) !void {
	rl.beginMode2D(self.camera);
	for (self.map.items) |rec| {
		rl.drawRectangleRec(rec, .blue);
	}
	rl.drawRectangleRec(player.rectangle(), .white);
	// the outlines are drawn in a separate loop to ensure they're on top
	// of every solid rectangle. this involves a bit of overhead because of
	// the need to run over the array twice.
	for (self.map.items, 0..) |rec, i| {
		if (self.selected.isSet(i))
			rl.drawRectangleLinesEx(rec, 3.0, .white);
	}

	rl.drawRectangleLinesEx(root.rectangleTipTail(self.selectorTip, self.selectorTail), 3.0, .white);
	rl.drawRectangleRec(root.rectangleTipTail(self.boxTail, self.boxTip), .blue);
	rl.endMode2D();
	var buffer = [_]u8{0} ** 0x200;
	{
		const s1 = try std.fmt.bufPrint(&buffer, "mode: {s}", .{self.mode.name()});
		buffer[s1.len] = 0;
		const s2 = buffer[0..s1.len :0];
		rl.drawText(s2, 400, 200, 21, .white);
	}
	if (self.mode == .edit) {
		const s2 =
			\\move: Z
			\\copy: C
			\\select: lclick
			\\scroll: rclick
			\\union select: shift + lclick
		;
		rl.drawText(s2, 400, 260, 21, .white);
	}
}

inline fn handleBuildInput(self: *Self, gpa: std.mem.Allocator) !void {
	const mousePos: rl.Vector2 =
		rl.getMousePosition().add(self.camera.target);

	if (rl.isMouseButtonPressed(.left)) {
		self.boxTip = mousePos;
		self.boxTail = mousePos;
	} else if (rl.isMouseButtonDown(.left)) {
		self.boxTail = mousePos;
	} else if (rl.isMouseButtonReleased(.left) and self.boxTail.equals(self.boxTip) == 0) {
		try self.map.append(gpa, root.rectangleTipTail(self.boxTip, self.boxTail));
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
			if (root.isInRectangle(rec, mousePos)) {
				self.selected.toggle(i);
				break;
			}
		}
	} else if (rl.isMouseButtonDown(.left) and !rl.isKeyDown(.z)) l1: {
		self.selectorTail = mousePos;
		if (mouseDelta.lengthSqr() == 0.0) break :l1;
		for (self.map.items, 0..) |rec, i| {
			if (rl.checkCollisionRecs(root.rectangleTipTail(self.selectorTip,
			self.selectorTail), rec)) {
				self.selected.set(i);
			} else if (!rl.isKeyDown(.left_shift))
				self.selected.unset(i);
		}
	} else {
		self.selectorTail = self.selectorTip;
	}

	const bitLen: usize = self.selected.bit_length;
	std.debug.assert(bitLen == self.map.items.len);
	if (rl.isKeyPressed(.delete)) {
		var indexes = try std.ArrayList(usize).initCapacity(gpa, self.map.items.len);
		defer indexes.deinit(gpa);
		for (0..bitLen) |i| if (self.selected.isSet(i)) {
			try indexes.append(gpa, i);
			self.selected.unset(i);
		};
		self.map.orderedRemoveMany(indexes.items);
		const newlen = @as(i64, @intCast(bitLen))
			- @as(i64,@intCast(indexes.items.len));
		if (newlen < 0) unreachable;
		try self.selected.resize(gpa, @as(usize,@intCast(newlen)), false);
	} else if (rl.isKeyDown(.z)) {
		for (0..bitLen) |i| l: {
			if (!self.selected.isSet(i)) break :l;
			self.map.items[i].x += mouseDelta.x;
			self.map.items[i].y += mouseDelta.y;
		}
	} else if (rl.isKeyPressed(.c)) {
		const count = self.selected.count();
		try self.map.ensureTotalCapacity(gpa, self.map.items.len + count);
		try self.selected.resize(gpa, bitLen + count, true);
		for (0..bitLen) |i| {
			if (!self.selected.isSet(i)) continue;
			try self.map.append(gpa, root.translate(rl.Rectangle,
				.{.x = 10, .y = 10}, self.map.items[i]));
			self.selected.unset(i);
		}
	}
}
