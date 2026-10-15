const root: type = @import("root.zig");
const Player = root.Player;
const std = @import("std");
const rl = @import("raylib");
const rgui = @import("raygui");

const Seconds = f32;
const Self = @This();
const kInputs = [_]rl.KeyboardKey{ .e, .s, .d, .f };
const tileSizes = [_]f32{64,32,16,8};

const Material = enum {
    normal,
    impulse,
    bounce,
    sticky,

    pub const color_map: std.enums.EnumMap(@This(), rl.Color) = .init(.{
        .normal = .dark_blue,
        .impulse = .violet,
        .bounce = .red,
        .sticky = .lime,
    });
};

gpa: std.mem.Allocator,
grid_mode: bool,
grid: root.Grid2D,
map: std.ArrayList(rl.Rectangle),
materials: std.ArrayList(Material),
box_tip: rl.Vector2,
box_tail: rl.Vector2,
box_material: Material,
selector_tip: rl.Vector2,
selector_tail: rl.Vector2,
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
    self.gpa = gpa;
    self.grid_mode = false;
    self.grid = try .initSquare(tileSizes[2], .zero());
    self.map = try .initCapacity(gpa, 0x40);
    self.mode = .scroll;
    self.camera = .{ .offset = .{ .x = 0, .y = 0 }, .rotation = 0, .target = .{ .x = 0, .y = 0 }, .zoom = 1 };

    try root.loadRectsFromFile("map.bin", gpa, &self.map);
    self.selected = try .initEmpty(gpa, self.map.items.len);
    self.materials = .empty; // this line can probably be commented out
    try self.materials.resize(gpa, self.map.items.len);
    @memset(self.materials.items, .normal);
}

pub fn deinit(self: *Self) void {
    self.map.deinit(self.gpa);
    self.materials.deinit(self.gpa);
    self.selected.deinit(self.gpa);
}

pub fn update(self: *Self, delta: Seconds) !void {
    _ = delta;

    if (rl.isMouseButtonDown(.right)) {
        self.camera.target = self.camera.target.subtract(rl.getMouseDelta());
    }

    switch (self.mode) {
    .build => try self.handleBuildInput(),
    .edit => try self.handleEditInput(),
    else => {},
    }

    inline for (@typeInfo(Material).@"enum".fields, 0..) |field, i| {
        if (rgui.button(.{
            .x = 40 + 250*i, .y = root.screenV().y - 90.0,
            .width = 220, .height = 60 }, field.name)
        ) {
            self.box_material = @enumFromInt(field.value);
            break;
        }
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
    
    _ = rgui.checkBox(.init(40, 40+80*3, 30,30), "grid mode", &self.grid_mode);
    
    if (rgui.button(.{ .x = 40, .y = 40 + 80*6, .width = 200,
    .height = 60 }, "load")) {
        self.map.shrinkAndFree(self.gpa, 0);
        try root.loadRectsFromFile("map.bin", self.gpa, &self.map);
        self.selected.unsetAll();
        try self.selected.resize(self.gpa, self.map.items.len, false);
    }
}

pub fn draw(self: Self, player: *Player) !void {
    rl.beginMode2D(self.camera);
    for (self.map.items, 0..) |rec, i| {
        rl.drawRectangleRec(rec,
            Material.color_map.get(self.materials.items[i]).?);
    }
    for (self.map.items) |rec| {
        // rl.drawRectangleRec(rec, .blue);
        rl.drawCircleV(.init(rec.x, rec.y), 1.2, .red);
    }
    rl.drawRectangleRec(player.rectangle(), .white);

    // the outlines are drawn in a separate loop to ensure they're on top
    // of every solid rectangle. this involves a bit of overhead because of
    // the need to run over the array twice.
    for (self.map.items, 0..) |rec, i| {
        if (self.selected.isSet(i)) {
            rl.drawRectangleLinesEx(rec, 2.5, .dark_blue);
        }
    }

    rl.drawRectangleLinesEx(root.rectangleTipTail(self.selector_tip, self.selector_tail), 2.5, .white);

    const box = root.rectangleTipTail(self.box_tail, self.box_tip);
    rl.drawRectangleRec(
        if (self.grid_mode) self.grid.alignAndFitRec(box)
        else box,
        .dark_blue);
    rl.drawRectangleRec(try self.tileAtMouse(), .init(255,255,255,100));

    if (self.grid_mode) {
        self.grid.draw(root.rectangleV(self.camera.target
            .add(self.camera.offset.scale(-1)), root.screenV()),
            .init(255,255,255,90), 1);
    }
    rl.endMode2D();

    _ = rgui.label(.{.x = 20, .y = root.screenV().y - 120.0,
        .width = root.screenV().x, .height = 120 }, "Block material");

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

fn tileAtMouse(self: @This()) !rl.Rectangle {
    const mousePos = rl.getMousePosition().add(self.camera.target);
    // return root.Grid2D.initCamera(self.camera, root.screenV(),.init(tileSizes[2],
    //     tileSizes[2])
    // ).tileAt(mousePos, .zero());
    return self.grid.tileAt(mousePos);
}

fn handleBuildInput(self: *Self) !void {
    const mousePos: rl.Vector2 =
        rl.getMousePosition().add(self.camera.target);

    if (rl.isMouseButtonPressed(.left)) {
        self.box_tip = mousePos;
        self.box_tail = mousePos;
    } else if (rl.isMouseButtonDown(.left)) {
        self.box_tail = mousePos;
    } else if (rl.isMouseButtonReleased(.left) and self.box_tail.equals(self.box_tip) == 0) {
        try self.map.append(self.gpa, self.grid.alignAndFitRec(
            root.rectangleTipTail(self.box_tip, self.box_tail)));
        try self.materials.append(self.gpa, self.box_material);
        try self.selected.resize(self.gpa, self.map.items.len, false);
    } else {
        self.box_tip = self.box_tail;
    }
}

fn handleEditInput(self: *Self) !void {
    const mousePos: rl.Vector2 =
        rl.getMousePosition().add(self.camera.target);
    const mouseDelta = rl.getMouseDelta();

    const tile = try self.tileAtMouse();
    _ = tile; // autofix

    if (rl.isMouseButtonPressed(.left)) l1: {
        if (rl.isKeyDown(.z)) break :l1;
        self.selector_tip = mousePos;
        self.selector_tail = mousePos;
        if (!rl.isKeyDown(.left_shift))
            self.selected.unsetAll();
        for (self.map.items, 0..) |rec, i| {
            if (root.isInRectangle(rec, mousePos)) {
                self.selected.toggle(i);
                break;
            }
        }
    } else if (rl.isMouseButtonDown(.left) and !rl.isKeyDown(.z)) l1: {
        self.selector_tail = mousePos;
        if (mouseDelta.lengthSqr() == 0.0) break :l1;
        for (self.map.items, 0..) |rec, i| {
            if (rl.checkCollisionRecs(root.rectangleTipTail(self.selector_tip,
            self.selector_tail), rec)) {
                self.selected.set(i);
            } else if (!rl.isKeyDown(.left_shift))
                self.selected.unset(i);
        }
    } else {
        self.selector_tail = self.selector_tip;
    }

    const bitLen: usize = self.selected.bit_length;
    std.debug.assert(bitLen == self.map.items.len);

    if (rl.isKeyPressed(.g)) {
        for (0..bitLen) |i| if (self.selected.isSet(i)) {
            self.map.items[i] = self.grid.alignRec(self.map.items[i]);
        } ;
    }

    
    if (rl.isKeyPressed(.delete)) {
        var indexes = try std.ArrayList(usize).initCapacity(self.gpa, self.map.items.len);
        defer indexes.deinit(self.gpa);
        for (0..bitLen) |i| if (self.selected.isSet(i)) {
            try indexes.append(self.gpa, i);
            self.selected.unset(i);
        };
        self.map.orderedRemoveMany(indexes.items);
        const newlen = @as(i64, @intCast(bitLen))
            - @as(i64,@intCast(indexes.items.len));
        if (newlen < 0) unreachable;
        try self.selected.resize(self.gpa, @as(usize,@intCast(newlen)), false);
    } else if (rl.isMouseButtonDown(.middle)) {
        for (0..bitLen) |i| l: {
            if (!self.selected.isSet(i)) break :l;
            self.map.items[i].x += mouseDelta.x;
            self.map.items[i].y += mouseDelta.y;
        }
    } else if (rl.isKeyPressed(.c)) {
        const count = self.selected.count();
        try self.map.ensureTotalCapacity(self.gpa, self.map.items.len + count);
        try self.selected.resize(self.gpa, bitLen + count, true);
        for (0..bitLen) |i| {
            if (!self.selected.isSet(i)) continue;
            try self.map.append(self.gpa, root.translate(rl.Rectangle,
                .{.x = 10, .y = 10}, self.map.items[i]));
            self.selected.unset(i);
        }
    }
}
