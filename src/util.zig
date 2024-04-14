const std = @import("std");

// TODO: This can be updated to use std.mem.span and then allocator.dupeZ for better performance
pub fn toCString(input: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    const buffer_len = input.len + 1;
    const buffer = try allocator.alloc(u8, buffer_len);
    std.mem.copyForwards(u8, buffer, input);
    buffer[buffer_len - 1] = 0;
    return buffer[0 .. buffer.len - 1 :0];
}

// TODO: Unused for now but will be udpated with an optimization pass
// pub fn toCStringPool(input: []const u8, location: []u8) void {
//     const buffer_len = input.len + 1;
//     std.mem.copyForwards(u8, location, input);
//     location[buffer_len - 1] = 0;
// }
