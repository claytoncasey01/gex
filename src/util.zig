const std = @import("std");

// TODO: This can be updated to use std.mem.span and then allocator.dupeZ for better performance
pub fn toCString(input: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    const buffer_len = input.len + 1;
    const buffer = try allocator.alloc(u8, buffer_len);
    std.mem.copyForwards(u8, buffer, input);
    buffer[buffer_len - 1] = 0;
    return buffer[0 .. buffer.len - 1 :0];
}

test "toCString" {
    const allocator = std.testing.allocator;
    const input = "Hello, World!";
    const c_string = try toCString(input, allocator);
    defer allocator.free(c_string);
    try std.testing.expectEqualStrings(input, c_string);
}
