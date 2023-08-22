const std = @import("std");
const print = std.fmt.comptimePrint;

pub const Direction = enum(u8) {
    forward = '0',
    backward = '1',
    both = '2',
};

pub const Scope = enum(u8) {
    screen = 'J',
    line = 'K',
};

pub inline fn default(comptime s: Scope, comptime d: Direction) []const u8 {
    return print("\x1b[{}{}", .{ d, s });
}

pub inline fn screen(comptime d: Direction) []const u8 {
    return default(Scope.screen, d);
}

pub inline fn line(comptime d: Direction) []const u8 {
    return default(Scope.line, d);
}
