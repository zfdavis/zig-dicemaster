const std = @import("std");
const parseUnsigned = std.fmt.parseUnsigned;
const isSpace = std.ascii.isSpace;

const Expr = union(enum) {
    constant: u32,
    roll: Roll,
};

const Roll = struct { dice: u32, sides: u32 };

const TokenIterator = struct {
    buffer: []const u8,
    index: usize = 0,

    pub fn next(self: *@This()) ?[]const u8 {
        while (self.index < self.buffer.len and isSpace(self.buffer[self.index])) : (self.index += 1) {}
        const start = self.index;

        if (start == self.buffer.len) return null;

        while (self.index < self.buffer.len and !isSpace(self.buffer[self.index])) : (self.index += 1) {}
        const end = self.index;

        return self.buffer[start..end];
    }
};

pub fn main() !void {
    var prng = std.rand.Xoroshiro128{ .s = @bitCast([2]u64, std.time.nanoTimestamp()) };
    const allocator = std.heap.c_allocator;
    const random = prng.random();
    const stderr = std.io.getStdErr().writer();
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var es: ?[]const Expr = null;
    defer if (es) |exprs| allocator.free(exprs);

    while (true) {
        const line = stdin.readUntilDelimiterAlloc(allocator, '\n', std.math.maxInt(usize)) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };
        defer allocator.free(line);

        if (line.len != 0) {
            if (parseExprs(allocator, line)) |exprs| {
                if (es) |old_es| allocator.free(old_es);
                es = exprs;
            } else |err| {
                try stderr.print("Invalid Input: {s}\n", .{err});
            }
        } else if (es) |exprs| {
            try stdout.print("{}\n", .{runExprs(random, exprs)});
        } else {
            try stderr.writeAll("Invalid Input: NoPrevLine\n");
        }
    }
}

fn parseExprs(allocator: std.mem.Allocator, input: []const u8) ![]Expr {
    var tokens = TokenIterator{ .buffer = input };
    var exprs = std.ArrayList(Expr).init(allocator);
    errdefer exprs.deinit();

    while (tokens.next()) |token| {
        if (std.mem.indexOfScalar(u8, token, 'd')) |mid| {
            const dice = try parseUnsigned(u32, token[0..mid], 10);
            const sides = try parseUnsigned(u32, token[mid + 1 ..], 10);
            if (sides < 1) return error.TooFewSides;
            try exprs.append(Expr{ .roll = Roll{ .dice = dice, .sides = sides } });
        } else {
            const constant = try parseUnsigned(u32, token, 10);
            try exprs.append(Expr{ .constant = constant });
        }
    }

    return exprs.toOwnedSlice();
}

fn runExprs(random: std.rand.Random, exprs: []const Expr) u32 {
    var sum: u32 = 0;

    for (exprs) |expr| {
        sum += switch (expr) {
            Expr.constant => |constant| constant,
            Expr.roll => |roll| runRoll(random, roll.dice, roll.sides),
        };
    }

    return sum;
}

fn runRoll(random: std.rand.Random, dice: u32, sides: u32) u32 {
    var roll: u32 = 0;
    var i: u32 = 0;

    while (i < dice) : (i += 1) {
        roll += random.intRangeAtMost(u32, 1, sides);
    }

    return roll;
}
