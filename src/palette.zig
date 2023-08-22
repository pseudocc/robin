const std = @import("std");
const print = std.fmt.comptimePrint;

pub const Color = enum(u8) {
    black = 0,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    reset = 9,
};

pub inline fn fg(comptime color: Color) []const u8 {
    return print("\x1b[3{d}m", .{@intFromEnum(color)});
}

pub inline fn bg(comptime color: Color) []const u8 {
    return print("\x1b[4{d}m", .{@intFromEnum(color)});
}

pub const reset = print("{s}{s}", .{ fg(.reset), bg(.reset) });
