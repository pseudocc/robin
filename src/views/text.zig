const std = @import("std");

const base = @import("base.zig");
const clear = @import("../clear.zig");

pub const TextFileView = struct {
    base: base.ViewBase,

    const Self = @This();

    pub fn append_text(self: *Self, text: []const u8) !void {
        const has_record = self.base.records.items.len > 0;
        const cursor = self.base.cursor;

        var parts = std.mem.splitSequence(u8, text, "\n");
        var first = parts.next().?;
        try self.base.records.append(.{
            .position = if (!has_record) cursor else null,
            .sequence = first,
        });
        self.base.cursor.x += @intCast(first.len);

        while (parts.next()) |part| {
            try self.start_newline();
            try self.base.records.append(.{ .sequence = part });
            self.base.cursor.x = @intCast(part.len);
        }
    }

    pub fn start_newline(self: *Self) !void {
        self.base.cursor.x = 0;
        self.base.cursor.y += 1;
        try self.base.records.append(.{
            .position = self.base.cursor,
        });
    }
};
