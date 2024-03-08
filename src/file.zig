const std = @import("std");
const io = std.io;
const fs = std.fs;
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;

// TODO: We will want to make the color configurable here.
pub fn searchFile(path: []const u8, search_for: []const u8, results: *std.ArrayList(FoundItem), allocator: std.mem.Allocator) !void {
    var file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;
    var index_of: ?usize = null;
    var line_number: u32 = 1;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_number += 1) {
        index_of = std.mem.indexOf(u8, line, search_for) orelse continue;

        if (index_of) |word_index| {
            const line_copy = try allocator.dupe(u8, line);
            try results.append(FoundItem{ .line_number = line_number, .line = line_copy, .index = word_index });
            index_of = null;
        }
    }
}
