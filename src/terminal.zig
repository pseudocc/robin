const std = @import("std");
const sys = std.os.system;

const Size = @import("views/base.zig").Size;

const XTerm256 = Terminal(.XTERM_256_COLOR);
const XTerm = Terminal(.XTERM_COLOR);

pub const Kind = enum(u8) {
    XTERM_256_COLOR = 0,
    XTERM_COLOR = 1,

    const Self = @This();

    pub fn get() !Self {
        var term = std.os.getenv("TERM") orelse "";
        if (std.mem.eql(u8, term, "xterm-256color")) {
            return .XTERM_256_COLOR;
        } else if (std.mem.eql(u8, term, "xterm-kitty")) {
            return .XTERM_256_COLOR;
        } else if (std.mem.eql(u8, term, "xterm-color")) {
            return .XTERM_COLOR;
        }

        std.log.err("Unsupported terminal type: {s}\n", .{term});
        return error.NotSupported;
    }

    pub fn enter_altbuf(self: Self) []const u8 {
        return switch (self) {
            .XTERM_256_COLOR => "\x1b[?1049h",
            .XTERM_COLOR => "\x1b7\x1b[?47h",
        };
    }

    pub fn leave_altbuf(self: Self) []const u8 {
        return switch (self) {
            .XTERM_256_COLOR => "\x1b[?1049l",
            .XTERM_COLOR => "\x1b[2J\x1b[?47l\x1b8",
        };
    }
};

pub const Toggles = enum(u8) {
    RawMode = 0,
    AltBuffer = 1,
};

pub const Terminal = struct {
    canonical: std.os.termios,
    raw: std.os.termios,
    fd: std.os.system.fd_t,
    flags: u32,
    kind: Kind,

    const Self = @This();

    pub fn init(kind: Kind, fd: std.os.system.fd_t) !Self {
        // https://viewsourcecode.org/snaptoken/kilo/02.enteringRawMode.html
        var canonical = try std.os.tcgetattr(fd);
        var raw = canonical;

        raw.iflag &= ~(sys.BRKINT | sys.ICRNL | sys.INPCK |
            sys.ISTRIP | sys.IXON);
        raw.oflag &= ~(sys.OPOST);
        raw.cflag |= (sys.CS8);
        raw.lflag &= ~(sys.ECHO | sys.ICANON | sys.IEXTEN | sys.ISIG);

        // blocking read with timeout
        raw.cc[sys.V.MIN] = 0;
        raw.cc[sys.V.TIME] = 1;

        return Self{
            .canonical = canonical,
            .raw = raw,
            .fd = fd,
            .flags = 0,
            .kind = kind,
        };
    }

    pub fn is_enabled(self: *Self, comptime mode: Toggles) bool {
        return (self.flags & @as(u32, 1 << @intFromEnum(mode))) != 0;
    }

    pub fn enable(self: *Self, comptime mode: Toggles) !void {
        if (self.is_enabled(mode)) {
            return;
        }
        _ = switch (mode) {
            .RawMode => try std.os.tcsetattr(self.fd, .FLUSH, self.raw),
            .AltBuffer => try std.os.write(self.fd, self.kind.enter_altbuf()),
        };
        self.flags |= @as(u32, 1 << @intFromEnum(mode));
    }

    pub fn disable(self: *Self, comptime mode: Toggles) !void {
        if (!self.is_enabled(mode)) {
            return;
        }
        _ = switch (mode) {
            .RawMode => try std.os.tcsetattr(self.fd, .FLUSH, self.canonical),
            .AltBuffer => try std.os.write(self.fd, self.kind.leave_altbuf()),
        };
        self.flags &= ~@as(u32, 1 << @intFromEnum(mode));
    }

    pub fn size(self: *Self) !Size {
        var sz: sys.winsize = undefined;
        const exit = sys.ioctl(self.fd, sys.T.IOCGWINSZ, @intFromPtr(&sz));
        if (exit != 0) {
            return error.IOCTL;
        }
        return Size{
            .width = sz.ws_col,
            .height = sz.ws_row,
        };
    }
};
