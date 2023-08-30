const std = @import("std");
const builtin = @import("builtin");
const terminal = @import("terminal.zig");
const editor = @import("editor.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const DEBUG = builtin.mode == .Debug;

pub fn main() !void {
    const BUFSIZ = if (DEBUG) 32 else 1024;
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

    var buffer: [BUFSIZ]u8 = undefined;
    var offset: usize = 0;
    main_loop: while (true) {
        const bytes_read = try stdin.read(buffer[offset..]);
        const end = offset + bytes_read;
        if (end == 0) {
            try e.idle();
            continue;
        }

        const has_input = bytes_read != 0;
        const bytes_processed = e.input(
            buffer[0..end],
            !has_input,
        ) catch {
            break :main_loop;
        };

        const unused = end - bytes_processed;
        if (unused != 0) {
            @memcpy(buffer[0..unused], buffer[bytes_processed..end]);
        }
        offset = unused;
    }

    inline for (modes) |mode| {
        try t.disable(mode);
    }
}
