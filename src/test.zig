const rlzig = @import("rlzig");
const std = rlzig.std;
const rl = rlzig.rl;
const rgui = rlzig.rgui;

const State = struct {
    const default = std.mem.zeroes(@This());
    pub fn init(self: *@This()) void {
        _ = self;
    }
    pub fn deinit(self: *@This()) void {_ = self;}
    pub fn update(self: *@This(), delta: f32) void {
        _ = .{delta, &self};
    }

    pub fn draw(self: @This()) void {
        _ = self;
    }
};

var state: State = .default;

pub fn main() void {
}
