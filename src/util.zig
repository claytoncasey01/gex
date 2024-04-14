const std = @import("std");
const Benchmark = @import("deps/zBench//zbench.zig").Benchmark;

// TODO: This can be updated to use std.mem.span and then allocator.dupeZ for better performance
pub fn toCString(input: []const u8, allocator: std.mem.Allocator) ![:0]const u8 {
    const buffer_len = input.len + 1;
    const buffer = try allocator.alloc(u8, buffer_len);
    std.mem.copyForwards(u8, buffer, input);
    buffer[buffer_len - 1] = 0;
    return buffer[0 .. buffer.len - 1 :0];
}

fn benchmarkToCString(allocator: std.mem.Allocator) void {
    const input = "Hello, World!";
    const c_string = toCString(input, allocator) catch unreachable;
    allocator.free(c_string);
}

test "toCString" {
    const allocator = std.testing.allocator;
    const input = "Hello, World!";
    const c_string = try toCString(input, allocator);
    defer allocator.free(c_string);
    try std.testing.expectEqualStrings(input, c_string);
}

test "Benchmark toCString" {
    const allocator = std.testing.allocator;
    var bench = Benchmark.init(allocator, .{});
    defer bench.deinit();
    try bench.add("toCString", benchmarkToCString, .{});
    try bench.run(std.io.getStdOut().writer());
}

// TODO: Unused for now but will be udpated with an optimization pass
// pub fn toCStringPool(input: []const u8, location: []u8) void {
//     const buffer_len = input.len + 1;
//     std.mem.copyForwards(u8, location, input);
//     location[buffer_len - 1] = 0;
// }
