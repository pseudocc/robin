const std = @import("std");

const cursor = @import("../cursor.zig");
const Writer = @import("../editor.zig").Editor.Writer;

pub const Position = struct {
    x: u16,
    y: u16,
};

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const RenderRecord = struct {
    position: ?Position = null,
    sequence: []const u8 = "",
};

pub const ViewBase = struct {
    offset: Position,
    size: Size,
    cursor: Position,
    zindex: u32,
    records: std.ArrayList(RenderRecord),

    const Self = @This();

    pub fn render(self: *Self, writer: *Writer) !void {
        const records = self.records.items;
        for (records) |record| {
            if (record.position != null) {
                const true_x = self.offset.x + record.position.?.x + 1;
                const true_y = self.offset.y + record.position.?.y + 1;
                _ = try writer.write(cursor.to(true_x, true_y));
            }
            _ = try writer.write(record.sequence);
        }
        self.records.clearRetainingCapacity();
    }
};

pub const TextFileView = @import("text.zig").TextFileView;
pub const RobinBarView = @import("bar.zig").RobinBarView;

pub const ViewTrait = union(enum) {
    text: *TextFileView,
    bar: *RobinBarView,

    const Self = @This();

    pub fn render(self: *Self, writer: *Writer) !void {
        switch (self.*) {
            inline else => |view| try view.base.render(writer),
        }
    }
};
