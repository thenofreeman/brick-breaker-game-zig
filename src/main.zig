const std = @import("std");
// const eql = std.mem.eql;
const ArrayList = std.ArrayList;

const rl = @import("raylib");

const rand = std.crypto.random;

const State = enum {
    MENU,
    PLAYING,
    PAUSED,
    NEXTLEVEL,
    GAMEOVER,
};

const Game = struct {
    window: rl.Vector2 = .{
        .x = 800,
        .y = 450,
    },

    topLeftCorner: rl.Vector2 = .{ .x = 0, .y = 0 },
    topRightCorner: rl.Vector2 = .{ .x = 800, .y = 0, },
    bottomLeftCorner: rl.Vector2 = .{ .x = 0, .y = 450, },
    bottomRightCorner: rl.Vector2 = .{ .x = 800, .y = 450, },
};

const Player = struct {
    body: rl.Rectangle,
    color: rl.Color,

    speed: f32 = 10,
    velocity: rl.Vector2 = .{ .x = 0, .y = 0 },

    lives: u8,

    pub fn init() Player {
        const dim: rl.Vector2 = .{ .x = 100, .y = 15 };
        const pos: rl.Vector2 = .{ .x = game.window.x / 2.0, .y = game.window.y - dim.y * 2.0 };

        var newPlayer: Player = .{
            .body = rl.Rectangle.init( pos.x, pos.y, dim.x, dim.y ),
            .color = .red,
            .lives = 3,
        };

        newPlayer.reset();

        return newPlayer;
    }

    pub fn reset(self: *Player) void {
        _ = self;
    }

    pub fn setDirection(self: *Player, direction: i2) void {
        self.velocity.x = @as(f32, @floatFromInt(direction)) * self.speed;
    }

    pub fn update(self: *Player) void {
        self.body.x += self.velocity.x;
        self.body.y += self.velocity.y;
    }

    pub fn draw(self: Player) void {
        rl.drawRectangleRec(self.body, self.color);
    }

};

const Ball = struct {
    n: u4,
    pos: rl.Vector2,
    radius: f32,
    color: rl.Color,

    speed: f32 = 4,
    velocity: rl.Vector2 = .{ .x = 5, .y = 5 },

    pub fn init(n: u4) Ball {
        var newBall: Ball = .{
            .n = n,
            .pos = undefined,
            .radius = 8,
            .color = .white,
        };

        newBall.reset();

        return newBall;
    }

    pub fn setXDirection(self: *Ball, dir: i2) void {
        self.velocity.x = @as(f32, @floatFromInt(dir)) * self.speed;
    }

    pub fn setYDirection(self: *Ball, dir: i2) void {
        self.velocity.y = @as(f32, @floatFromInt(dir)) * self.speed;
    }

    pub fn reset(self: *Ball) void {
        self.pos = .{
            .x = game.window.x / 3.0 + @as(f32, @floatFromInt(rand.intRangeAtMost(u16, 0, @intFromFloat(game.window.x / 3.0)))),
            .y = game.window.y / 3.0 + @as(f32, @floatFromInt(rand.intRangeAtMost(u16, 0, @intFromFloat(game.window.y / 3.0)))),
        };

        self.setXDirection(if (rand.boolean()) 1 else -1);
        self.setYDirection(if (rand.boolean()) 1 else -1);
    }

    pub fn update(self: *Ball) void {
        self.pos.x += self.velocity.x;
        self.pos.y += self.velocity.y;
    }

    pub fn draw(self: Ball) void {
        rl.drawCircleV(self.pos, self.radius, self.color);
    }

};

const Brick = struct {
    body: rl.Rectangle,
    color: rl.Color,
    show: bool,

    pub fn init(pos: rl.Vector2, dim: rl.Vector2, color: rl.Color) Brick {
        return .{
            .body = .{
                .x = pos.x,
                .y = pos.y,
                .width = dim.x,
                .height = dim.y
            },
            .color = color,
            .show = true,
        };
    }

    pub fn draw(self: Brick) void {
        if (!self.show) return;

        rl.drawRectangleRec(self.body, self.color);
    }

    pub fn setShow(self: *Brick, show: bool) void {
        self.show = show;
    }
};

fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        list: ArrayList(T),
        count: u16,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .list = ArrayList(T).init(allocator),
                .count = 0,
            };
        }

        pub fn deinit(self: Self) void {
            self.list.deinit();
        }

        pub fn add(self: *Self, el: T) !void {
            try self.list.append(el);
            if (el.show) {
                self.count += 1;
            }
        }
    };
}

// global
const game = Game{}; // var soon

pub fn main() anyerror!void {
    rl.initWindow(@intFromFloat(game.window.x),
                  @intFromFloat(game.window.y),
                  "Pong!");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var player = Player.init();
    var ball = Ball.init(1);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // const grid =
    //     \\----------
    //     \\----RR----
    //     \\---G--G---
    //     \\--B----B--
    //     \\---G--G---
    //     \\----RR----
    //     \\----------
    //     ;
    const grid =
        \\----------
        \\---RRRR---
        \\--G----G--
        \\-B--YY--B-
        \\-B--YY--B-
        \\--G----G--
        \\---RRRR---
        ;

    var brickGrid = Grid(Brick).init(arena.allocator());
    defer brickGrid.deinit();

    const ncols = 10;
    const nrows = grid.len / ncols;
    const brickSize: rl.Vector2 = .{
        .x = game.window.x / @as(f32, @floatFromInt(ncols)),
        .y = game.window.y / 2.0 / @as(f32, @floatFromInt(nrows)),
    };

    for (grid, 0..) |c, i| {
        const color = switch(c) {
            'R' => rl.Color.red,
            'G' => rl.Color.green,
            'B' => rl.Color.blue,
            'Y' => rl.Color.yellow,
            '-' => rl.Color.alpha(rl.Color.black, 0),
            '\n' => rl.Color.alpha(rl.Color.black, 0), // should find a better fix
            else => rl.Color.alpha(rl.Color.white, 0), // shouldn't be seen
        };


        const xpos = brickSize.x * @as(f32, @floatFromInt(i % (ncols+1)));
        const ypos = brickSize.y * @as(f32, @floatFromInt(i / (ncols+1)));

        try brickGrid.add(Brick{
            .body = .{
                .x = xpos,
                .y = ypos,
                .width = brickSize.x,
                .height = brickSize.y,
            },
            .color = color,
            .show = (c != '-' and c != '\n'),
        });
    }

    var state: State = .MENU;

    while(!rl.windowShouldClose()) {
        switch (state) {
            .MENU => {
                if (rl.isKeyPressed(.space)) {
                    state = .PLAYING;
                }

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

                rl.drawText("Brick Breaker!", 320, 200, 20, rl.Color.light_gray);
            },
            .PLAYING => {
                if (rl.isKeyDown(.left)) {
                    player.setDirection(-1);
                } else if (rl.isKeyDown(.right)) {
                    player.setDirection(1);
                } else {
                    player.setDirection(0);
                }

                if (rl.isKeyPressed(.space)) {
                    state = .PAUSED;
                }

                if (rl.isKeyPressed(.r)) {
                    ball.reset();
                }

                if (player.lives < 0) {
                    state = .GAMEOVER;
                }

                if (brickGrid.count <= 0) {
                    state = .NEXTLEVEL;
                }

                player.update();
                ball.update();

                if (rl.checkCollisionCircleRec(ball.pos, ball.radius, player.body)) {
                    if (ball.pos.x < player.body.x) {
                        ball.setXDirection(-1);
                    } else if (ball.pos.x >= player.body.x + player.body.width) {
                        ball.setXDirection(1);
                    } else {
                        ball.setYDirection(-1);
                    }
                }

                if (rl.checkCollisionCircleLine(ball.pos, ball.radius, game.topLeftCorner, game.bottomLeftCorner)) {
                    ball.setXDirection(1);
                } else if (rl.checkCollisionCircleLine(ball.pos, ball.radius, game.topRightCorner, game.bottomRightCorner)) {
                    ball.setXDirection(-1);
                }

                if (rl.checkCollisionCircleLine(ball.pos, ball.radius, game.topLeftCorner, game.topRightCorner)) {
                    ball.setYDirection(1);
                }

                // handle brick collisions
                for (brickGrid.list.items) |*brick| {
                    if (rl.checkCollisionCircleRec(ball.pos, ball.radius, brick.body)) {
                        if (brick.show) {
                            if (ball.pos.x < brick.body.x) {
                                ball.setXDirection(-1);
                            } else if (ball.pos.x > brick.body.x + brick.body.width) {
                                ball.setXDirection(1);
                            }

                            if (ball.pos.y > brick.body.y) {
                                ball.setYDirection(1);
                            } else if (ball.pos.y < brick.body.y + brick.body.height) {
                                ball.setYDirection(-1);
                            }

                            brickGrid.count -= 1;
                            brick.setShow(false);
                        }

                    }

                }

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

                for (brickGrid.list.items) |brick| {
                    brick.draw();
                }

                player.draw();
                ball.draw();

                // draw lives and score
            },
            .PAUSED => {
                if (rl.isKeyPressed(.space)) {
                    state = .PLAYING;
                }

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

                rl.drawText("Paused.", 380, 200, 20, rl.Color.light_gray);
            },
            .NEXTLEVEL => {
                if (rl.isKeyPressed(.space)) {
                    state = .MENU;
                }

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

                rl.drawText("WINNER!", 380, 200, 20, rl.Color.light_gray);

            },
            .GAMEOVER => {
                if (rl.isKeyPressed(.space)) {
                    state = .MENU;
                    player.reset();
                }

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

                rl.drawText("Game OVer!", 300, 200, 20, rl.Color.light_gray);
            }
        }
    }

}
