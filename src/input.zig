const std = @import("std");
const io = std.io;
const fs = std.fs;
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;

pub const SearchOptions = struct {
    input_file: ?*const fs.File = null,
    haystack: ?[]const u8 = null,
    needle: []const u8,
    results: *std.ArrayList(FoundItem),
    allocator: std.mem.Allocator,
};

// TODO: Return an error here if both haystack and input_file are null.
pub fn search(options: SearchOptions) !void {
    if (options.input_file) |file| {
        try searchFileOrStdIn(file, options.needle, options.results, options.allocator);
    } else if (options.haystack) |haystack| {
        try searchText(haystack, options.needle, options.results);
    }
}

// TODO: We will want to make the color configurable here.
fn searchFileOrStdIn(input_file: *const std.fs.File, needle: []const u8, results: *std.ArrayList(FoundItem), allocator: std.mem.Allocator) !void {
    var buf_reader = io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;
    var index_of: ?usize = null;
    var line_number: u32 = 1;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_number += 1) {
        index_of = std.mem.indexOf(u8, line, needle) orelse continue;

        if (index_of) |word_index| {
            const line_copy = try allocator.dupe(u8, line);
            try results.append(FoundItem{ .line_number = line_number, .line = line_copy, .index = word_index });
            index_of = null;
        }
    }
}

// Takes a string to be searched and a string to search for. It will return
// a modified version of the to_seach with all the instances of needle highlighted
// NOTE: It might be useful to update this to also return some statistics about the search,
// like the number of matches, the indexes of the matches, etc.
fn searchText(haystack: []const u8, needle: []const u8, found: *std.ArrayList(FoundItem)) !void {
    var haystack_lines = std.mem.splitSequence(u8, haystack, "\n");
    var cursor: usize = 1;
    var index_of: usize = undefined;

    while (haystack_lines.next()) |line| {
        index_of = std.mem.indexOf(u8, line, needle) orelse continue;

        if (index_of > 0) {
            try found.append(FoundItem{ .line_number = cursor, .line = line, .index = index_of });
            cursor += 1;
        }
    }
}
