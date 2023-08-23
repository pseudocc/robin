const std = @import("std");
const sys = std.os.system;

pub const Terminal = struct {
    canonical: std.os.termios,
    raw: std.os.termios,
    fd: std.os.system.fd_t,
    enabled: bool = false,

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

        raw.cc[sys.V.MIN] = 0;
        raw.cc[sys.V.TIME] = 1;

        return Self{
            .canonical = canonical,
            .raw = raw,
            .fd = fd,
        };
    }

    pub fn blocking(self: *Self, set: bool) !void {
        var raw = self.raw;
        if (set) {
            raw.cc[sys.V.TIME] = 1;
        } else {
            raw.cc[sys.V.TIME] = 0;
        }
        if (self.enabled) {
            try std.os.tcsetattr(self.fd, .FLUSH, raw);
        }
    }

    pub fn enable(self: *Self) !void {
        try std.os.tcsetattr(self.fd, .FLUSH, self.raw);
        self.enabled = true;
    }

    pub fn disable(self: *Self) !void {
        try std.os.tcsetattr(self.fd, .FLUSH, self.canonical);
        self.enabled = false;
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
