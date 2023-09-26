const std = @import("std");

const base = @import("base.zig");
const clear = @import("../clear.zig");

pub const RobinBarView = struct {
    base: base.ViewBase,

    const Self = @This();

    pub fn set_text(self: *Self, text: []const u8) !void {
        try self.base.records.append(.{
            .position = .{ .x = 0, .y = 0 },
            .sequence = clear.line(.both),
        });
        try self.base.records.append(.{
            .sequence = text,
        });
    }
};
