const std = @import("std");

pub inline fn print(buf: []u8, comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.bufPrint(buf, fmt, args) catch unreachable;
}

pub inline fn to(x: u16, y: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d};{d}H", .{ y, x });
}

pub inline fn up(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}A", .{n});
}

pub inline fn down(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}B", .{n});
}

pub inline fn right(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}C", .{n});
}

pub inline fn left(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}D", .{n});
}

pub inline fn next_line(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}E", .{n});
}

pub inline fn prev_line(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}F", .{n});
}

pub inline fn column(n: u16) []const u8 {
    var buf: [16]u8 = undefined;
    return print(&buf, "\x1b[{d}G", .{n});
}

pub const hide = "\x1b[?25l";
pub const show = "\x1b[?25h";

pub const save = "\x1b[s";
pub const restore = "\x1b[u";
