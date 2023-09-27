const std = @import("std");
const builtin = @import("builtin");

const cursor = @import("cursor.zig");
const clear = @import("clear.zig");
const terminal = @import("terminal.zig");
const view = @import("views/base.zig");

const Size = @import("views/base.zig").Size;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const FileWriter = std.fs.File.Writer;

const DEBUG = builtin.mode == .Debug;
const QMARK = std.unicode.utf8Decode("�") catch unreachable;

pub const Editor = struct {
    const BufferedWriter = std.io.BufferedWriter(1024, FileWriter);
    pub const Writer = BufferedWriter.Writer;

    const Reason = error{
        Quit,
        Abort,
        WriteError,
    };

    allocator: Allocator,
    size: Size,
    buffer: BufferedWriter,
    needs_sync: bool = false,
    arena: ArenaAllocator,
    views: ArrayList(view.ViewTrait),

    // testing only
    text_file: view.TextFileView,
    robin_bar: view.RobinBarView,

    const Self = @This();
    pub fn init(allocator: Allocator, output: FileWriter, size: Size) !Self {
        var buffer = BufferedWriter{ .unbuffered_writer = output };

        var self = Self{
            .allocator = allocator,
            .size = size,
            .buffer = buffer,
            .arena = ArenaAllocator.init(allocator),
            .views = ArrayList(view.ViewTrait).init(allocator),
            .robin_bar = .{
                .base = .{
                    .size = .{
                        .width = size.width,
                        .height = 1,
                    },
                    .offset = .{ .x = 0, .y = size.height - 1 },
                    .cursor = .{ .x = 0, .y = 0 },
                    .zindex = 1,
                    .records = ArrayList(view.RenderRecord).init(allocator),
                },
            },
            .text_file = .{
                .base = .{
                    .size = .{
                        .width = size.width,
                        .height = size.height - 1,
                    },
                    .offset = .{ .x = 0, .y = 0 },
                    .cursor = .{ .x = 0, .y = 0 },
                    .zindex = 0,
                    .records = ArrayList(view.RenderRecord).init(allocator),
                    .focused = true,
                },
            },
        };

        try self.clear_screen();

        return self;
    }

    pub fn input(self: *Self, data: []const u8, force: bool) !usize {
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

        if (data.len < 16) {
            try self.render();
        } else {
            self.needs_sync = true;
        }
        return i;
    }

    pub fn idle(self: *Self) !void {
        if (self.needs_sync) {
            self.needs_sync = false;
            try self.render();
        }
    }

    fn handle_ascii(self: *Self, byte: u8) !void {
        if (byte == 'q') {
            return Reason.Quit;
        }
        var allocator = self.arena.allocator();
        var bar: []const u8 = undefined;
        if (std.ascii.isControl(byte)) {
            bar = try std.fmt.allocPrint(allocator, "Control: {d}", .{byte});
            if (byte == std.ascii.control_code.cr)
                try self.text_file.start_newline();
        } else {
            bar = try std.fmt.allocPrint(
                allocator,
                "ASCII: {d} ({c})",
                .{ byte, byte },
            );
            const text = try std.fmt.allocPrint(allocator, "{c}", .{byte});
            try self.text_file.append_text(text);
        }
        try self.robin_bar.set_text(bar);
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
        var writer = self.buffer.writer();
        for (self.views.items) |v| {
            try @constCast(&v).render(&writer);
        }
        _ = try writer.write(cursor.restore);
        try self.buffer.flush();
        _ = self.arena.reset(.{ .retain_with_limit = 8 * 1024 * 1024 });
    }

    pub fn deinit(self: *Self) !void {
        try self.clear_screen();
        self.arena.deinit();
        self.views.deinit();
        // testing only
        self.text_file.base.records.deinit();
        self.robin_bar.base.records.deinit();
    }
};
