const std = @import("std");
const io = std.io;
const fs = std.fs;
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;
const Match = @import("regex.zig").Match;
const Regex = @import("regex.zig").Regex;
const WordPosition = @import("regex.zig").WordPosition;

pub const SearchOptions = struct {
    input_file: ?*const fs.File = null,
    haystack: ?[]const u8 = null,
    needle: []const u8,
    results: *std.ArrayList(FoundItem),
    matches: ?*std.ArrayList(Match) = null,
    regex_path: bool = false,
    allocator: std.mem.Allocator,
};

// TODO: Return an error here if both haystack and input_file are null.
pub fn search(options: SearchOptions) !void {
    if (options.input_file) |file| {
        // Handle the regex code path sepearately for now
        if (options.regex_path) {
            if (options.matches) |matches| {
                std.debug.print("Searching file with regex\n", .{});
                try searchFileOrStdInRegex(file, options.needle, matches, options.allocator);
            } else {
                unreachable;
            }
        } else {
            try searchFileOrStdIn(file, options.needle, options.results, options.allocator);
        }
    } else if (options.haystack) |haystack| {
        if (options.regex_path) {
            if (options.matches) |matches| {
                std.debug.print("Searching text with regex\n", .{});
                try searchTextRegex(haystack, options.needle, matches, options.allocator);
            } else {
                unreachable;
            }
        } else {
            try searchText(haystack, options.needle, options.results);
        }
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

fn searchFileOrStdInRegex(input_file: *const std.fs.File, needle: []const u8, matches: *std.ArrayList(Match), allocator: std.mem.Allocator) !void {
    var buf_reader = io.bufferedReader(input_file.reader());
    var in_stream = buf_reader.reader();
    var buf: [4096]u8 = undefined;
    var line_number: u32 = 1;

    const regex = try Regex.compile(needle, allocator);
    defer regex.deinit();

    var word_position: WordPosition = undefined;

    while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| : (line_number += 1) {
        word_position = try regex.exec(line);
        if (word_position.end == 0) continue;
        try matches.append(try Match.init(line, line_number, word_position, allocator));
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

fn searchTextRegex(haystack: []const u8, needle: []const u8, matches: *std.ArrayList(Match), allocator: std.mem.Allocator) !void {
    const regex = try Regex.compile(needle, allocator);
    defer regex.deinit();

    var word_position: WordPosition = undefined;
    var haystack_lines = std.mem.splitSequence(u8, haystack, "\n");
    var cursor: usize = 1;

    while (haystack_lines.next()) |line| {
        word_position = try regex.exec(line);
        if (word_position.end == 0) continue;
        try matches.append(try Match.init(line, cursor, word_position, allocator));
        cursor += 1;
    }
}
