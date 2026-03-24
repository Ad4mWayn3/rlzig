const rlzig = @import("rlzig");
const std = rlzig.std;
const rl = rlzig.rl;
const rgui = rlzig.rgui;

const State = struct {
    camera: rl.Camera2D,
    grid: Grid2D,

    pub fn init(self: *@This()) void {
        self.camera = .{.offset = .{.x=0,.y=0},
            .target = .{.x=0,.y=0},
            .rotation = 0,
            .zoom = 1,};
        self.grid = .{.spacing = .init(20,20),
            .viewport = .init(0,0,400,400)};
    }
    pub fn deinit(self: *@This()) void {_ = self;}
    pub fn update(self: *@This(), delta: f32) void {
        _ = delta;
        const v = rl.getMouseDelta();
        if (rl.isMouseButtonDown(.middle))
            self.camera.target = .add(self.camera.target, v.scale(-1))
        else if (rl.isMouseButtonDown(.right)) {
            self.grid.viewport.width += v.x;
            self.grid.viewport.height += v.y;
        } else if (rl.isMouseButtonDown(.left)) {
            self.grid.viewport.x += v.x;
            self.grid.viewport.y += v.y;
        }

        if (rl.isKeyDown(.left_shift))
            self.grid.spacing = .add(self.grid.spacing, v);
    }

    pub fn draw(self: @This()) void {
        rl.beginMode2D(self.camera);
        rl.drawRectangleRec(self.grid.tileAt(
                rl.getMousePosition().add(self.camera.target), .zero()
            ),
            .light_gray
        );
        self.grid.draw(self.grid.origin(),.init(0,0xff,0xff,0x80), 1.5);
        rl.endMode2D();
    }
};

var state: State = undefined;

const Grid2D = struct {
    viewport: rl.Rectangle,
    spacing: rl.Vector2,

    pub fn initCamera(camera: rl.Camera2D, size: rl.Vector2, spacing: rl.Vector2
    ) @This() {
        const t, const o = .{camera.target, camera.offset};
        return .{
            .viewport = .{
                .x = t.x-o.x, .y = t.y-o.y,
                .width = size.x, .height = size.y,
            },
            .spacing = spacing,
        };
    }

    pub fn draw(self: @This(), offset: rl.Vector2,
        color: rl.Color, thick: f32
    ) void {
        std.debug.assert(self.spacing.x*self.spacing.y != 0);
        const sp, const vp = .{self.spacing, self.viewport};
        const ofs: rl.Vector2 = .init(@mod(-offset.x,sp.x), @mod(-offset.y,sp.y));
        var x, var y = .{vp.x+ofs.x,vp.y+ofs.y};
        while (x < vp.x+vp.width): (x += sp.x)
            rl.drawLineEx(.{.x=x,.y=vp.y},.{.x=x,.y=vp.y+vp.height}, thick, color);
        while (y < vp.y+vp.height): (y += sp.y)
            rl.drawLineEx(.{.x=vp.x,.y=y},.{.x=vp.x+vp.width,.y=y}, thick, color);
    }

    pub fn intersectionAt(self: @This(), p: rl.Vector2, offset: rl.Vector2
    ) rl.Vector2 {
        _ = offset;
        var x, var y = .{p.x/self.spacing.x, p.y/self.spacing.y};
        const xmin, const xmax = .{@floor(x), @ceil(x)};
        const ymin, const ymax = .{@floor(y), @ceil(y)};
        x = if (@abs(xmin-p.x) <= @abs(xmax-p.x)) xmin else xmax;
        y = if (@abs(ymin-p.y) <= @abs(ymax-p.y)) ymin else ymax;
        return .init(x,y);
    }

    pub fn tileAt(self: @This(), p: rl.Vector2, offset: rl.Vector2) rl.Rectangle {
        _ = offset;
        const x, const y = .{@floor(p.x/self.spacing.x),
            @floor(p.y/self.spacing.y)};
        const newP: rl.Vector2 = .init(self.spacing.x*x,self.spacing.y*y);
        return .init(newP.x,newP.y,self.spacing.x,self.spacing.y);
    }

    pub fn origin(self: @This()) rl.Vector2 {
        return .init(self.viewport.x, self.viewport.y);
    }
};

pub fn main() !void {
    rl.setTraceLogLevel(.warning);
    rl.initWindow(1600, 900, "follow camera");
    defer rl.closeWindow();

    state.init();
    defer state.deinit();

    while (!rl.windowShouldClose()) {
        const delta = rl.getFrameTime();
        state.update(delta);

        rl.beginDrawing();
        rl.clearBackground(.black);
        state.draw();
        rl.endDrawing();
    }
}