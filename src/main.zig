const std = @import("std");
const terminal = @import("terminal.zig");
const editor = @import("editor.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

pub fn main() !void {
    const modes = [_]terminal.Toggles{
        .RawMode,
        .AltBuffer,
    };

    const kind = try terminal.Kind.get();
    var t = try terminal.Terminal.init(kind, stdin.handle);

    inline for (modes) |mode| {
        try t.enable(mode);
    }

    var e = try editor.Editor.init(stdout, try t.size());
    defer e.deinit() catch unreachable;

    var buffer: [32]u8 = undefined;
    main_loop: while (true) {
        const bytes_read = try stdin.read(&buffer);
        if (bytes_read == 0) {
            continue;
        }

        for (buffer[0..bytes_read]) |byte| {
            e.key(byte) catch {
                break :main_loop;
            };
        }

        try e.render();
    }

    inline for (modes) |mode| {
        try t.disable(mode);
    }
}
