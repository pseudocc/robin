const std = @import("std");
const print = std.fmt.comptimePrint;

pub const Direction = enum(u8) {
    forward = 0,
    backward = 1,
    both = 2,
};

pub const Scope = enum(u8) {
    screen = 'J',
    line = 'K',
    char = 'X',
};

pub fn rchar(allocator: std.mem.Allocator, n: u16) ![]const u8 {
    return try switch (n) {
        0, 1 => std.fmt.allocPrint(allocator, "\x1b[X", .{}),
        else => std.fmt.allocPrint(allocator, "\x1b[{d}X", .{n}),
    };
}

inline fn ctime(comptime s: Scope, comptime n: u16) []const u8 {
    if (n == 0) return print("\x1b[{c}", .{@intFromEnum(s)});
    return print("\x1b[{d}{c}", .{ n, @intFromEnum(s) });
}

pub inline fn screen(comptime d: Direction) []const u8 {
    return ctime(Scope.screen, @intFromEnum(d));
}

pub inline fn line(comptime d: Direction) []const u8 {
    return ctime(Scope.line, @intFromEnum(d));
}

pub inline fn char(comptime n: u16) []const u8 {
    return ctime(Scope.char, n);
}
