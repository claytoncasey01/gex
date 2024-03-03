const std = @import("std");
const io = std.io;
const fs = std.fs;
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("formatter.zig").colorizeWord;
const Color = @import("formatter.zig").Color;

// TODO: We will want to make the color configurable here.
pub fn searchFile(path: []const u8, search_for: []const u8, color: ?Color, results: *std.ArrayList(FoundItem)) !void {
    const allocator = results.allocator;
    var file = try fs.cwd().openFile(path, .{});
    defer file.close();

    var buf_reader = io.bufferedReader(file.reader());
    var in_stream = buf_reader.reader();
    var buf: [2048]u8 = undefined;
    var index_of: ?usize = null;
    var line_number: u32 = 1;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_number += 1) {
        index_of = std.mem.indexOf(u8, line, search_for) orelse continue;

        if (index_of) |word_index| {
            const line_copy = try allocator.dupe(u8, line);
            const colorized = try colorizeWord(line_copy, search_for, color orelse Color.green, allocator);
            try results.append(FoundItem{ .line_number = line_number, .line = colorized, .index = word_index });
            index_of = null;
        }
    }
}
