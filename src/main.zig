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

    try editor.init(allocator);
    defer editor.deinit(allocator);
    try platformer.init(allocator, editor.map.items, &printBuffer);
    
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
