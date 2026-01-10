const Editor = @import("editor");
const rlzig = @import("rlzig");
const std: type = rlzig.std;
const rl: type = rlzig.rl;
const rgui: type = rlzig.rgui;

const allocator = std.heap.page_allocator;
var game: Editor = undefined;

pub fn main() !void {
    try game.init(allocator);
    defer game.deinit(allocator);

    rl.setTraceLogLevel(.warning);
    rl.setExitKey(.null);
    rl.setTargetFPS(60);
    rl.initWindow(800, 600, "rlzig!");
    defer rl.closeWindow();
    rl.setWindowPosition(80,80);

    const m = rl.getCurrentMonitor();
    var x = @Vector(2,i32){rl.getMonitorWidth(m), rl.getMonitorHeight(m)};
    x *= [_]i32{4}**2;
    x /= [_]i32{5}**2;
    rl.traceLog(.info, "calculated resolution: %dx%d\n", .{x[0],x[1]});
    rl.setWindowSize(x[0], x[1]);
    rgui.setStyle(.default, .{ .default = .text_size }, 21);

    while (!rl.windowShouldClose()) {
        rl.clearBackground(.black);
        rl.beginDrawing();
        try game.draw();
        rl.endDrawing();

        try game.update(allocator, rl.getFrameTime());
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
