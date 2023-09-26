const std = @import("std");

fn Parameter(comptime T: type) type {
    return struct {
        long_name: ?[]const u8 = null,
        short_name: u8 = 0,
        description: []const u8 = "",
        metavar: ?[]const u8 = null,
        default: ?T = null,
        value: ?T = null,
        allocator: ?std.mem.Allocator = null,
        ref: *T,

        const Self = @This();

        fn match_option(self: *Self, raw: []const u8) bool {
            if (raw[0] != '-') {
                return false;
            }
            if (raw.len == 2 and raw[1] == self.short_name) {
                return true;
            }
            if (raw[1] != '-') {
                return false;
            }
            if (raw.len >= 2 and std.mem.eql(u8, raw[2..], self.long_name.?)) {
                return true;
            }
            return false;
        }

        pub fn enter(self: *Self, args: [][:0]u8, i: *usize) !bool {
            if (self.value != null) {
                return false;
            } else if (self.short_name == 0 and self.long_name == null) {
                try self.take(args, i);
                return true;
            } else if (self.match_option(args[i.*])) {
                i.* += 1;
                try self.take(args, i);
                return true;
            }
            return false;
        }

        pub fn take(self: *Self, args: [][:0]u8, i: *usize) !void {
            switch (T) {
                inline bool => {
                    self.value = true;
                    return;
                },
                inline []const u8 => {
                    if (i.* >= args.len) {
                        return error.MissingValue;
                    }
                    self.value = args[i.*];
                    i.* += 1;
                    return;
                },
                inline [][]const u8 => {
                    if (i.* >= args.len) {
                        return error.MissingValue;
                    }
                    var list = std.ArrayList([]const u8).init(self.allocator.?);
                    while (i.* < args.len and args[i.*][0] != '-') {
                        try list.append(args[i.*]);
                        i.* += 1;
                    }
                    self.value = list.items;
                },
                inline else => @compileError("Unsupported type"),
            }
        }

        pub fn post(self: *Self) !void {
            if (self.value == null) {
                if (self.default == null) {
                    return error.MissingValue;
                }
                self.value = self.default;
            }
            self.ref.* = self.value.?;
        }

        pub fn print_help(self: *const Self) !void {
            var stdout = std.io.getStdOut().writer();
            try stdout.print("  ", .{});
            if (self.long_name != null) {
                try stdout.print("--{s}", .{self.long_name.?});
                if (self.short_name != 0) {
                    try stdout.print(", ", .{});
                }
            }
            if (self.short_name != 0) {
                try stdout.print("-{c}", .{self.short_name});
            }
            if (self.metavar != null) {
                if (self.long_name != null or self.short_name != 0) {
                    try stdout.print(" ", .{});
                }
                try stdout.print("{s}", .{self.metavar.?});
            }
            try stdout.print("\n", .{});
            if (self.description.len != 0) {
                try stdout.print("      {s}\n", .{self.description});
            }
        }
    };
}

const ParameterTrait = union(enum) {
    boolean: *Parameter(bool),
    string: *Parameter([]const u8),
    strings: *Parameter([][]const u8),

    const Self = @This();

    pub fn enter(self: *Self, args: [][:0]u8, i: *usize) !bool {
        return switch (self.*) {
            inline else => |p| p.enter(args, i),
        };
    }

    pub fn post(self: *Self) !void {
        return switch (self.*) {
            inline else => |p| p.post(),
        };
    }

    pub fn print_help(self: *const Self) !void {
        return switch (self.*) {
            inline else => |p| p.print_help(),
        };
    }
};

pub const Arguments = struct {
    arena: std.heap.ArenaAllocator,
    name: []const u8,
    version: []const u8,

    show_version: bool = undefined,
    show_help: bool = undefined,
    files: [][]const u8 = undefined,
    commands: [][]const u8 = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        version: []const u8,
    ) Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        var self = Self{
            .arena = arena,
            .name = name,
            .version = version,
        };
        return self;
    }

    pub fn parse(self: *Self) !void {
        var allocator = self.arena.allocator();

        var help = Parameter(bool){
            .long_name = "help",
            .short_name = 'h',
            .description = "print the help message",
            .default = false,
            .ref = &self.show_help,
        };
        var version = Parameter(bool){
            .long_name = "version",
            .short_name = 'v',
            .description = try std.fmt.allocPrint(
                allocator,
                "print the version of {s}",
                .{self.name},
            ),
            .default = false,
            .ref = &self.show_version,
        };
        var files = Parameter([][]const u8){
            .description = "file(s) to edit",
            .metavar = "FILE..",
            .default = &.{},
            .ref = &self.files,
            .allocator = allocator,
        };
        var commands = Parameter([][]const u8){
            .long_name = "",
            .description = "command(s) to run",
            .metavar = "COMMAND..",
            .default = &.{},
            .ref = &self.commands,
            .allocator = allocator,
        };

        var parameters = [_]ParameterTrait{
            .{ .boolean = &help },
            .{ .boolean = &version },
            .{ .strings = &files },
            .{ .strings = &commands },
        };

        const args = try std.process.argsAlloc(allocator);
        errdefer self.deinit();

        var i: usize = 1;
        while (i < args.len) {
            var found = false;
            for (0..parameters.len) |j| {
                var p = parameters[j];
                found = try p.enter(args, &i);
                if (found) {
                    break;
                }
            }
            if (!found) {
                return error.InvalidOption;
            }
        }

        for (0..parameters.len) |j| {
            var p = parameters[j];
            try p.post();
        }

        if (self.show_help) {
            try self.print_help(parameters[0..2], parameters[2..]);
            std.os.exit(0);
        } else if (self.show_version) {
            try self.print_version();
            std.os.exit(0);
        }
    }

    pub fn print_help(self: *Self, options: []const ParameterTrait, positionals: []const ParameterTrait) !void {
        var stdout = std.io.getStdOut().writer();
        try stdout.print(
            "Usage: {s} [OPTIONS] [FILE..] [--] [COMMAND..]\n",
            .{self.name},
        );
        try stdout.print("\n", .{});
        try stdout.print("Options:\n", .{});
        for (options) |p| {
            try p.print_help();
        }
        if (positionals.len != 0) {
            try stdout.print("\n", .{});
            try stdout.print("Positionals Arguments:\n", .{});
            for (positionals) |p| {
                try p.print_help();
            }
        }
        try stdout.print("\n", .{});
        try stdout.print("{s}: {s}\n", .{ self.name, self.version });
    }

    pub fn print_version(self: *Self) !void {
        var stdout = std.io.getStdOut().writer();
        try stdout.print("{s}\n", .{self.version});
    }

    pub fn deinit(self: *Arguments) void {
        self.arena.deinit();
    }
};
