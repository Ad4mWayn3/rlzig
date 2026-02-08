const Editor = @import("editor");
const Platformer = @import("platformer");
const rlzig = @import("rlzig");
const std: type = rlzig.std;
const rl: type = rlzig.rl;
const rgui: type = rlzig.rgui;

const allocator = std.heap.page_allocator;
var editor: Editor = undefined;
var platformer: Platformer = undefined;
var printBuffer: [0x200]u8 = undefined;

pub fn main() !void {
    try editor.init(allocator);
    defer editor.deinit(allocator);
    try platformer.init(allocator, editor.map.items, &printBuffer);

    rl.setTraceLogLevel(.warning);
    rl.setExitKey(.null);
    rl.setTargetFPS(60);
    rl.initWindow(800, 600, "rlzig!");
    defer rl.closeWindow();
    rl.setWindowPosition(80,80);

    {const m = rl.getCurrentMonitor();
    var x = @Vector(2,i32){rl.getMonitorWidth(m), rl.getMonitorHeight(m)};
    x *= [_]i32{4}**2;
    x /= [_]i32{5}**2;
    rl.traceLog(.info, "calculated resolution: %dx%d\n", .{x[0],x[1]});
    rl.setWindowSize(x[0], x[1]);}
    
    rgui.setStyle(.default, .{ .default = .text_size }, 21);
    var mode: enum(u2) { platformer, editor } = .editor;

    while (!rl.windowShouldClose()) {
        if (rl.isKeyPressed(.tab)) {
            const len: usize =
                comptime @typeInfo(@TypeOf(mode)).@"enum".fields.len;
            mode = @enumFromInt((@intFromEnum(mode) +% 1) % len);
            if (mode == .platformer) platformer.map = editor.map.items;
        }
        rl.clearBackground(.black);
        rl.beginDrawing();
        rl.drawFPS(30,400);
        if (mode == .editor) try editor.draw(&platformer.player)
        else platformer.draw();
        rl.endDrawing();

        const delta = rl.getFrameTime();
        if (mode == .editor) try editor.update(allocator, delta)
        else try platformer.update(1.0/60.0);
        if (rl.isKeyPressed(.up)) {
            const tsize = rgui.getStyle(.default, .{ .default = .text_size });
            rgui.setStyle(.default, .{ .default = .text_size }, tsize + 1);
        }
        if (rl.isKeyPressed(.down)) {
            const tsize = rgui.getStyle(.default, .{ .default = .text_size });
            rgui.setStyle(.default, .{ .default = .text_size }, tsize - 1);
        }
    }
}

const State = struct {
    box1: rl.Rectangle = .{.x = 200, .y = 200, .width = 100, .height = 100},
    box2: rl.Rectangle = .{.x = 340, .y = 200, .width = 100, .height = 100},
    camera: rl.Camera2D = .{.target = .{.x = 0, .y = 0},
        .offset = .{.x=0, .y=0}, .rotation = 0, .zoom = 1},
    collide: bool = false,
    cursorDragging: bool = false,
};

var state = State {};

pub fn _main() !void {
    rl.setTraceLogLevel(.warning);
    //rl.setTargetFPS(20);
    rl.initWindow(1600,900,"collision test!");
    defer rl.closeWindow();
    while (!rl.windowShouldClose()) {
        const curPos = rl.getMousePosition().add(state.camera.target);
        if (rl.isMouseButtonPressed(.left) and rlzig.isInRectangle(state.box1, curPos)) {
            state.cursorDragging = true;
        }

        if (rl.isMouseButtonDown(.left) and state.cursorDragging) {
            const shift = rl.getMouseDelta();
            state.box1.x += shift.x;
            state.box1.y += shift.y;
        } else state.cursorDragging = false;

        if (rgui.button(.{.x=30,.y=30,.width=300,.height=40}, "toggle colissions"))
            state.collide = state.collide != true;
        
        if (state.collide and rl.checkCollisionRecs(state.box1, state.box2))
            rlzig.fixCollisionRecs(&state.box1, state.box2);

        rl.beginDrawing(); {
        rl.clearBackground(.{.r = 0, .g = 50, .b = 40, .a = 255});
        rl.drawRectangleRec(state.box2, .white);
        rl.drawRectangleRec(state.box1, .gray);

        if (rl.checkCollisionRecs(state.box1, state.box2)) {
            rl.drawRectangleLinesEx(state.box1, 3, .red);
        }
        } rl.endDrawing();
    }
}
