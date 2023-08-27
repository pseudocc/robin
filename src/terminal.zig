const std = @import("std");
const sys = std.os.system;

pub const Terminal = struct {
    canonical: std.os.termios,
    raw: std.os.termios,
    fd: std.os.system.fd_t,
    flags: u32,

    pub const Toggles = enum(u8) {
        RawMode = 0,
        AltBuffer = 1,
    };

    const Reason = error{
        TcgetattrFailed,
        IoctlFailed,
    };

    const Self = @This();

    pub fn init(fd: std.os.system.fd_t) !Self {
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
            .AltBuffer => try std.os.write(self.fd, "\x1b[?1049h"),
        };
        self.flags |= @as(u32, 1 << @intFromEnum(mode));
    }

    pub fn disable(self: *Self, comptime mode: Toggles) !void {
        if (!self.is_enabled(mode)) {
            return;
        }
        _ = switch (mode) {
            .RawMode => try std.os.tcsetattr(self.fd, .FLUSH, self.canonical),
            .AltBuffer => try std.os.write(self.fd, "\x1b[?1049l"),
        };
        self.flags &= ~@as(u32, 1 << @intFromEnum(mode));
    }

    pub fn size(self: *Self) error{IOCTL}!Size {
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

    pub const Size = struct {
        width: u16,
        height: u16,
    };
};
