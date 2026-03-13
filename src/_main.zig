const rlzig = @import("rlzig");
const std = rlzig.std;
const rl = rlzig.rl;
const rgui = rlzig.rgui;

const State = struct {
    const resolution = rl.Vector2{.x=1600,.y=900};
    point: rl.Vector2 = .{.x=0,.y=0},
    texture: rl.Texture2D,
    deadzone: rl.Rectangle = .{.x=0,.y=0,.width=400,.height=400},
    camera: rl.Camera2D = .{
        .target = .{.x=0,.y=0},
        .offset = .{.x=resolution.x/2.0,.y=resolution.y/2.0},
        .rotation = 0, .zoom = 1},
};

var state = State { .texture = undefined };

fn sdInterval(x: f32, inter: [2]f32) f32 {
    std.debug.assert(@min(inter[0], inter[1]) == inter[0]);
    return (x-inter[0]) - (inter[0]-inter[1])/2.0;
}

/// Minimum translation vector. Smallest trajectory `rec` should travel to
/// "meet" `v`. Assumes `v` is outside of `rec`
fn recVecMTV(v: rl.Vector2, rec: rl.Rectangle) rl.Vector2 {
    const clamp = std.math.clamp;
    return v.subtract(.{.x = clamp(v.x, rec.x, rec.x+rec.width),
        .y = clamp(v.y, rec.y, rec.y+rec.width)});
}

const DeadzoneCamera2D = struct {
    cam: *rl.Camera2D,
    deadzone: rl.Rectangle,
    pub fn follow(self: *@This(), p: rl.Vector2, delta: f32) void {
        if (!rl.checkCollisionPointRec(p, self.deadzone)) {
            const v = recVecMTV(p, self.deadzone).scale(delta*8.0);
            self.deadzone.x += v.x;
            self.deadzone.y += v.y;
            self.camera.target = rl.Vector2.init(self.deadzone.x, self.deadzone.y)
                .add(rl.Vector2.init(self.deadzone.width,self.deadzone.height)
                    .scale(0.5)
                );
        }
    }
};

pub fn _main() !void {
    rl.setTraceLogLevel(.warning);
    rl.setTargetFPS(30);
    rl.initWindow(1600, 900, "follow camera");
    defer rl.closeWindow();

    state.texture = try .init("GOD.png");
    defer state.texture.unload();

    while (!rl.windowShouldClose()) {
        if (rl.isMouseButtonDown(.left))
            state.point = state.point.add(rl.getMouseDelta());
        
        const delta = rl.getFrameTime();

        if (!rl.checkCollisionPointRec(state.point, state.deadzone)) {
            const v = recVecMTV(state.point, state.deadzone).scale(delta*8.0);
            state.deadzone.x += v.x;
            state.deadzone.y += v.y;
            state.camera.target = rl.Vector2.init(state.deadzone.x, state.deadzone.y)
                .add(rl.Vector2.init(state.deadzone.width,state.deadzone.height)
                    .scale(0.5)
                );
        }

        rl.clearBackground(.black);
        rl.beginDrawing();
        rl.beginMode2D(state.camera);
        state.texture.drawRec(.{.x=0,.y=0,
            .width=State.resolution.x, .height=State.resolution.y},
            State.resolution.scale(-0.5), .white);
        rl.drawCircleV(state.point, 20, .white);
        rl.drawRectangleLinesEx(state.deadzone, 4, .red);
        rl.endMode2D();
        rl.endDrawing();
    }
}