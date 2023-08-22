const std = @import("std");

pub const Style = enum(u8) {
    reset = 0,
    bold = 1,
    faint = 2,
    italic = 3,
    underline = 4,
    blink = 5,
    blink_fast = 6,
    invert = 7,
    hide = 8,
    strike = 9,

    doubly_underline = 21,
    normal_intensity = 22,
    not_italic = 23,
    not_underlined = 24,
    not_blinking = 25,
    not_inverted = 27,
    reveal = 28,
    not_strike = 29,
};

pub inline fn set(comptime style: Style) []const u8 {
    return std.fmt.comptimePrint("\x1b[{}m", .{@intFromEnum(style)});
}

pub const reset = set(.reset);
