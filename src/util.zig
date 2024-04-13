const std = @import("std");

pub fn toCString(input: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    const buffer_len = input.len + 1;
    const buffer = try allocator.alloc(u8, buffer_len);
    std.mem.copyForwards(u8, buffer, input);
    buffer[buffer_len - 1] = 0;
    return buffer[0 .. buffer.len - 1 :0];
}
