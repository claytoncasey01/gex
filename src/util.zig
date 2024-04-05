const std = @import("std");

pub fn toCString(input: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    // TODO: Pass in an allocator
    const result = try allocator.alloc(u8, input.len + 1);
    std.mem.copyForwards(u8, result, input);
    result[input.len] = 0;
    return result[0..input.len :0];
}
