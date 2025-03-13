const std = @import("std");
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

    speed: f32 = 7,
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

                if (player.lives < 0) {
                    state = .GAMEOVER;
                }

                player.update();
                ball.update();

                // handle wall collisions
                if (rl.checkCollisionCircleRec(ball.pos, ball.radius, player.body)) {
                    ball.setYDirection(-1);
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

                rl.beginDrawing();
                defer rl.endDrawing();

                rl.clearBackground(rl.Color.black);

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
