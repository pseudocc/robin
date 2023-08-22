const std = @import("std");
const palette = @import("palette.zig");
const terminal = @import("terminal.zig");
const cursor = @import("cursor.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    var bwriter = std.io.bufferedWriter(stdout);
    const bstdout = bwriter.writer();

    var term = try terminal.Terminal.init(stdin.handle);

    try term.enable();
    defer term.disable() catch unreachable;

    var buffer: [32]u8 = undefined;
    main_loop: while (true) {
        const bytes_read = try stdin.read(&buffer);
        if (bytes_read == 0) {
            continue;
        }
        for (buffer[0..bytes_read]) |byte| {
            if (byte == 'q') {
                try stdout.print("Exiting...\r\n", .{});
                break :main_loop;
            }
            if (std.ascii.isControl(byte)) {
                try bstdout.print("{d}\r\n", .{byte});
            } else {
                try bstdout.print("{d} ({c})\r\n", .{ byte, byte });
            }
        }
        try bwriter.flush();
    }
}
