const rlzig = @import("rlzig");
const rl = rlzig.rl;
const rmath = rl.math;
const std = rlzig.std;
const Self = @This();
const Input = rlzig.Input;
const Seconds = f32;
const Player = rlzig.Player;

const Collision = struct {
	horizontal: bool,
	vertical: bool,
	onGround: bool,
};

const InputName = enum(u4) {
	up = 0, down, left, right,
	jump, duck,
};

const InputMap = struct {
	pub const Parent = rlzig.EnumMap(InputName, Input);
	parent: Parent,

	pub fn is(self: *@This(), state: Input.State, name: InputName) bool {
		return Input.is(self.parent.at(name), state);
	}
};

var inputMap = InputMap{ .parent = .new(&.{
	.{.up, .{.keyboard = .e}},
	.{.down, .{.keyboard = .d}},
	.{.left, .{.keyboard = .s}},
	.{.right, .{.keyboard = .f}},
	.{.jump, .{.keyboard = .space}},
	.{.duck, .{.keyboard = .z}},
}) };

/// Physics constants:
const Physics = struct {
	const Float = f32;
	gravity: Float = 2000.0,
	hAccel: Float = 2000.0,
	maxHVel: Float = 400.0,
	jumpImpulse: Float = 600.0,
	minSpeedThreshold: Float = 1e-4,
};

var physics: Physics = .{};

map: []rl.Rectangle,
player: Player,
camera: rl.Camera2D,
rmd: rl.Vector2,
collision: Collision,
printBuffer: []u8,
inputHeldTime: [InputMap.Parent.count]Seconds,
movingOppositeH: bool = false,
movingOppositeT: Seconds = 0.0,
initDragVel: rl.Vector2 = .{.x = 0, .y = 0},

pub fn init(self: *Self, map: []rl.Rectangle, printBuffer: []u8) void {
	self.inputHeldTime = .{0.0} ** InputMap.Parent.count;
	self.map = map;
	self.printBuffer = printBuffer;
	self.rmd = .{ .x = 0, .y = 0 };
	self.collision = .{ .horizontal = false, .vertical = false,
		.onGround = false };
	self.player = .{
		.x = 0, .y = 0,
		.size = .{.x = 25, .y = 50},
		.vel = .{.x = 0, .y = 0},
		.orientation = .vertical,
	};
	std.debug.assert(self.player.x <= self.player.y);
	self.camera = .{
		.target = .{.x = 0, .y = 0},
		.offset = .{.x = 0, .y = 0},
		.rotation = 0.0,
		.zoom = 1.0,
	};
}

fn increaseHoldTime(self: *Self, input: InputName, time: Seconds) void {
	self.inputHeldTime[@intFromEnum(input)] += time;
}

pub fn update(self: *Self, delta: Seconds) void {
	var hmove = true;
	if (inputMap.is(.down, .right)) {
		self.player.vel.x += physics.hAccel * delta;
		self.movingOppositeH = self.player.vel.x < 0.0;
	} else if (inputMap.is(.down, .left)) {
		self.player.vel.x -= physics.hAccel * delta;
		self.movingOppositeH = self.player.vel.x > 0.0;
	} else hmove = false;

	self.player.orientation = if (inputMap.is(.down, .duck))
		.horizontal else .vertical;
	
	if (inputMap.is(.pressed, .jump) and self.collision.onGround) {
		self.player.vel.y = -physics.jumpImpulse;
	}
	self.player.vel.x = rmath.clamp(self.player.vel.x, -physics.maxHVel,
		physics.maxHVel);

	self.rmd = self.rmd.add(self.player.vel.scale(delta));
	const vel = @Vector(2,i32){
		@intFromFloat(std.math.sign(self.rmd.x)*@floor(@abs(self.rmd.x))),
		@intFromFloat(std.math.sign(self.rmd.y)*@floor(@abs(self.rmd.y)))
	};
	self.rmd.x -= @floatFromInt(vel[0]);
	self.rmd.y -= @floatFromInt(vel[1]);
	move(Player, rl.Rectangle, self.map, vel,
		&self.collision, &self.player);

	if (self.collision.vertical) {
		//self.collision.onGround = self.player.vel.y > 0.0;
		self.player.vel.y = 0.0;
	} else if (!collidingMany(&self.player.shifted(.{.x = 0, .y = 1}),
	self.map)) {
		self.player.vel.y += physics.gravity * delta;
	} else self.collision.onGround = true;

	if ((self.movingOppositeH or !hmove) and self.collision.onGround) blk: {
		self.movingOppositeT += delta;
		if (@abs(self.player.vel.x) < physics.minSpeedThreshold) {
			self.player.vel.x = 0.0;
			break :blk;
		}
		self.player.vel.x = self.initDragVel.x * std.math.pow(f32, 0.12,
			self.movingOppositeT*12.0);
	} else {
		self.movingOppositeT = 0.0;
		self.initDragVel.x = self.player.vel.x; 
	}

	if (self.collision.horizontal)
		self.player.vel.x = 0.0;
	self.camera.target =  self.player.pos().add(self.player.size.scale(0.5)).
		subtract(rlzig.screenV().scale(0.5));
}

pub fn draw(self: *Self) void {
	rl.beginMode2D(self.camera);
	for (self.map) |rec| rl.drawRectangleRec(rec, .blue);
	rl.drawRectangleRec(self.player.rectangle(), .white);
	rl.endMode2D();
	const printed = std.fmt.bufPrint(self.printBuffer,
		"on ground: {s}\x00",
		.{if (self.collision.onGround) "true" else "false"}
	) catch unreachable;
	std.debug.assert(printed[printed.len-1] == 0);
	rl.drawText(printed[0.. printed.len-1 :0], 30,30, 21, .white);
	rlzig.drawVecCentered(3.0, .light_gray, self.player.vel.scale(1.0/10.0));
}

/// Moves `obj` in integer steps along two axes, if collisions are found,
/// they're stored in `collision`, and `obj` steps back to the last
/// non-colliding position.
fn move(Movable: type, Solid: type, map: []Solid, vel: @Vector(2,i32),
	collision: *Collision, obj: *Movable
) void {
	std.debug.assert(!collidingMany(obj, map));
	_ = moveX(map, &collision.horizontal, obj, vel[0]);
	const y = moveY(map, &collision.vertical, obj, vel[1]);
	collision.onGround = y == 0 and vel[1] > 0;
}

fn moveX(map: anytype, collision: *bool, obj: anytype, vel: i32) usize {
	return moveAxis(map, obj, collision, vel, &obj.x);
}

fn moveY(map: anytype, collision: *bool, obj: anytype, vel: i32) usize {
	return moveAxis(map, obj, collision, vel, &obj.y);
}

/// Moves `obj` along `axis` in `vel` steps, or one step before
/// collision. `axis` is intended to be a member of `obj`, since I don't
/// know any way of ensuring this, this is juts a blueprint that implements
/// `moveX` and `moveY`.
fn moveAxis(map: anytype, obj: anytype, collision: *bool, vel: i32,     
	axis: *f32
) usize {
	const step: f16 = @floatFromInt(std.math.sign(vel));
	const steps: usize = @abs(vel);
	for (0..steps) |i| {
		axis.* += step;

		// very expensive operation, checking collisions against every object
		// every frame hurts efficiency in the long run.
		if (collidingMany(obj, map)) {
			axis.* -= step;
			collision.* = true;
			return i;
		}
	}
	collision.* = false;
	return steps;
}

fn recCenter(r: rl.Rectangle) rl.Vector2 {
	return .{.x = r.x + r.width/2.0, .y = r.y + r.height/2.0};
}

fn fastMove(map: []rl.Rectangle, player: *Player, vel: rl.Vector2) Collision {
	player.x += vel.x;
	player.y += vel.y;
	var out: Collision = .{.horizontal=false,.vertical=false,.onGround=false};
	for (map) |rec| if (rl.checkCollisionRecs(rec, player.rectangle())) {
		const prec = player.rectangle();
		const xint = rlzig.intersection(f32,
			.{rec.x, rec.x+rec.width},
			.{prec.x, prec.x+prec.width});
		const yint = rlzig.intersection(f32,
			.{rec.y, rec.y+rec.height},
			.{prec.y, prec.y+prec.height});
		std.debug.assert(xint > 0.0 and yint > 0.0); // maybe >= ?
		std.debug.assert(@min(xint,yint)+@max(xint,yint) == xint+yint);
		if (@min(xint,yint) == xint) out.vertical = true
		else out.horizontal = true;

		// var vec = recCenter(rec).subtract(recCenter(prec)).normalize();
		// vec.x *= xint;

	} ;
	return out;
}

fn _move(map: []rl.Rectangle, player: *Player, collision: *bool,
	vel: rl.Vector2,
) void {
	var newvel = vel;
	for (map) |rec| {
		if (willCollideWith(rec, player.rectangle(), newvel)) {
			collision.* = true;
			newvel = maxNonCollidingMotion(player.rectangle,rec,newvel);
		}
	}
	std.debug.assert(blk: {
		for (map) |rec| if (willCollideWith(player.rectangle, rec, newvel))
			break :blk false;
		break :blk true;
	});
	player.x += newvel.x;
	player.y += newvel.y;
}

fn collidingMany(movable: anytype, solids: anytype) bool {
	for (solids) |solid| if (colliding(movable, solid)) return true;
	return false;
}

fn willCollideWith(a: rl.Rectangle, b: rl.Rectangle, v: rl.Vector2) bool {
	const xs, const ys = .{rlzig.recPoints(a), rlzig.recPoints(b)};
	const vP = (rl.Vector2 {.x = -v.y, .y = v.x}).normalize();
	return rlzig.checkCollisionAxes(&xs, &ys, &.{vP,
		.{.x=1,.y=0}, .{.x=0,.y=1}});
}

/// Given rectangles `a` and `b`, if `a` moves along `v` in 1 unit of time
/// returns the time it takes for `a` to touch `b`
fn maxNonCollidingMotion(a: rl.Rectangle, b: rl.Rectangle, v: rl.Vector2
) rl.Vector2 {
	std.debug.assert(willCollideWith(a,b,v));
	const axm, const axM = .{a.x, a.x+a.width};
	const aym, const ayM = .{a.y, a.y+a.height};
	const bxm, const bxM = .{b.x, b.x+b.width};
	const bym, const byM = .{b.y, b.y+b.height};
	// am_i + t*v_i = bM_i
	// t = (bM_i - am_i)/v_i
	var tx = (bxM - axm)/v.x;
	std.debug.assert(tx <= 1.0);
	if (tx < 0.0)
		tx = (bxm - axM)/v.x;

	var ty = (byM - aym)/v.y;
	std.debug.assert(ty <= 1.0);
	if (ty < 0.0)
		ty = (bym - ayM)/v.y;

	return v.scale(@max(tx,ty));
}

fn colliding(movable: anytype, solid: anytype
) bool {
	const T = comptime @TypeOf(movable);
	const U = comptime @TypeOf(solid);
	if (T == rl.Rectangle and U == rl.Rectangle) {
		return rl.checkCollisionRecs(movable, solid);
	}
	else if (T == *Player or T == *const Player and U == rl.Rectangle) {
		return rl.checkCollisionRecs(@as(*const Player,movable).rectangle(), solid);
	}
	else @compileError("collision checking between "
		++ @typeName(T) ++ " and " ++ @typeName(U) ++ " is not defined");
}
