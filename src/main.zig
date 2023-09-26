const std = @import("std");
const builtin = @import("builtin");
const terminal = @import("terminal.zig");
const editor = @import("editor.zig");
const Arguments = @import("args.zig").Arguments;

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut().writer();
const stderr = std.io.getStdErr().writer();

const DEBUG = builtin.mode == .Debug;
const NAME = "robin";

const MAJOR_VERSION = 0;
const MINOR_VERSION = 0;
const PATCH_VERSION = 1;
const EXTRA_VERSION = if (DEBUG) "+dev" else "";
const VERSION = std.fmt.comptimePrint(
    "{d}.{d}.{d}{s}",
    .{
        MAJOR_VERSION,
        MINOR_VERSION,
        PATCH_VERSION,
        EXTRA_VERSION,
    },
);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const BUFSIZ = if (DEBUG) 32 else 1024;
    const modes = [_]terminal.Toggles{
        .RawMode,
        .AltBuffer,
    };

    var args = Arguments.init(allocator, NAME, VERSION);
    try args.parse();
    defer args.deinit();

    const kind = try terminal.Kind.get();
    var t = try terminal.Terminal.init(kind, stdin.handle);

    inline for (modes) |mode| {
        try t.enable(mode);
    }

    var e = try editor.Editor.init(allocator, stdout, try t.size());
    defer e.deinit() catch unreachable;

    // test only
    try e.views.append(.{ .text = &e.text_file });
    try e.views.append(.{ .bar = &e.robin_bar });

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
