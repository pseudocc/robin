const std = @import("std");
const cursor = @import("cursor.zig");
const clear = @import("clear.zig");
const terminal = @import("terminal.zig");

const Size = terminal.Terminal.Size;
const Writer = std.fs.File.Writer;

pub const Editor = struct {
    const Reason = error{
        Quit,
        Abort,
        WriteError,
    };

    size: Size,
    writer: Writer,

    const Self = @This();
    pub fn init(output: Writer, size: Size) !Self {
        var self = Self{
            .size = size,
            .writer = output,
        };

        try self.clear_screen();
        return self;
    }

    pub fn key(self: *Self, byte: u8) !void {
        if (byte == 'q') {
            return Reason.Quit;
        } else if (std.ascii.isControl(byte)) {
            try self.writer.print("{d}\r\n", .{byte});
        } else {
            try self.writer.print("{d} ({c})\r\n", .{ byte, byte });
        }
    }

    fn clear_screen(self: *Self) !void {
        try self.writer.print("{s}{s}", .{
            clear.screen(.both),
            cursor.to(0, 0),
        });
    }

    pub fn render(self: *Self) !void {
        _ = self;
    }

    pub fn deinit(self: *Self) !void {
        try self.clear_screen();
    }
};
