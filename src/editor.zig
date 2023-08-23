const std = @import("std");
const cursor = @import("cursor.zig");
const clear = @import("clear.zig");
const terminal = @import("terminal.zig");

const Size = terminal.Terminal.Size;
const Writer = std.fs.File.Writer;

pub const Editor = struct {
    const BufferedWriter = std.io.BufferedWriter(1024, Writer);

    const Reason = error{
        Quit,
        Abort,
        WriteError,
    };

    size: Size,
    buffer: BufferedWriter,

    const Self = @This();
    pub fn init(output: Writer, size: Size) !Self {
        var buffer = BufferedWriter{ .unbuffered_writer = output };

        var self = Self{
            .size = size,
            .buffer = buffer,
        };

        try self.clear_screen();
        return self;
    }

    pub fn key(self: *Self, byte: u8) !void {
        var writer = self.buffer.writer();
        if (byte == 'q') {
            return Reason.Quit;
        } else if (std.ascii.isControl(byte)) {
            try writer.print("{d}\r\n", .{byte});
        } else {
            try writer.print("{d} ({c})\r\n", .{ byte, byte });
        }
    }

    fn clear_screen(self: *Self) !void {
        var writer = self.buffer.writer();
        try writer.print("{s}{s}", .{
            clear.screen(.both),
            cursor.to(0, 0),
        });
        try self.buffer.flush();
    }

    pub fn render(self: *Self) !void {
        try self.buffer.flush();
    }

    pub fn deinit(self: *Self) !void {
        try self.clear_screen();
    }
};
