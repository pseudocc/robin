const std = @import("std");
const builtin = @import("builtin");
const cursor = @import("cursor.zig");
const clear = @import("clear.zig");
const terminal = @import("terminal.zig");

const Size = terminal.Size;
const Writer = std.fs.File.Writer;

const DEBUG = builtin.mode == .Debug;
const QMARK = std.unicode.utf8Decode("�") catch unreachable;

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

    pub fn input(self: *Self, data: []const u8, force: bool) !usize {
        if (DEBUG) {
            var writer = self.buffer.writer();
            try writer.print("data length: {d}\r\n", .{data.len});
        }

        var i: usize = 0;
        while (i < data.len) {
            const n = std.unicode.utf8ByteSequenceLength(data[i]) catch {
                try self.handle_unicode(QMARK);
                continue;
            };
            if (n == 1) {
                try self.handle_ascii(data[i]);
                i += 1;
                continue;
            } else if (!force and i + n > data.len) {
                break;
            }

            const codepoint = std.unicode.utf8Decode(data[i .. i + n]) //
            catch {
                try self.handle_unicode(QMARK);
                continue;
            };
            i += n;
            try self.handle_unicode(codepoint);
        }

        try self.render();
        return i;
    }

    fn handle_ascii(self: *Self, byte: u8) !void {
        var writer = self.buffer.writer();
        if (byte == @as(u21, 'q')) {
            return Reason.Quit;
        } else if (std.ascii.isControl(byte)) {
            try writer.print("{d}\r\n", .{byte});
        } else {
            try writer.print("{d} ({c})\r\n", .{ byte, byte });
        }
    }

    fn handle_unicode(self: *Self, code: u21) !void {
        const N = 4;
        var bytes: [N]u8 = [_]u8{0} ** N;
        var writer = self.buffer.writer();
        const n = try std.unicode.utf8Encode(code, &bytes);
        try writer.print("{s} ({d})\r\n", .{ bytes[0..@intCast(n)], code });
    }

    fn clear_screen(self: *Self) !void {
        var writer = self.buffer.writer();
        try writer.print("{s}{s}", .{
            clear.screen(.both),
            cursor.to(0, 0),
        });
        try self.buffer.flush();
    }

    fn render(self: *Self) !void {
        try self.buffer.flush();
    }

    pub fn deinit(self: *Self) !void {
        try self.clear_screen();
    }
};
