const std = @import("std");

pub const Size = struct {
    width: u16,
    height: u16,
};

pub const ViewBase = struct {
    size: Size,
};
