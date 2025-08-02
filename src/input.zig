const std = @import("std");
const io = std.io;
const fs = std.fs;
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("output.zig").colorizeWord;
const colorizeWordNoAlloc = @import("output.zig").colorizeWordNoAlloc;
const writeOutput = @import("output.zig").writeOutputNew;
const writeColorizedOutput = @import("output.zig").writeColorizedOutput;
const writeColorizedOutputNew = @import("output.zig").writeColorizedOutputSIMD;
const Color = @import("output.zig").Color;
const Match = @import("regex.zig").Match;
const Regex = @import("regex.zig").Regex;
const WordPosition = @import("regex.zig").WordPosition;

pub const SearchResults = struct {
    const Self = @This();
    // All raw file content in one contiguous block
    content_buffer: []u8,

    line_starts: std.ArrayList(u32),
    match_positions: std.ArrayList(u32),
    match_line_indices: std.ArrayList(u32),

    // Pre-allocated working buffers to avoid extra allocation overheads
    output_buffer: []u8, // Reuseable buffer for colorized output
    temp_buffer: []u8, // Working space for string ops

    // Metadata for efficient processing
    needle_len: u32,
    total_matches: u32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, estimated_file_size: usize) !SearchResults {
        // NOTE(casey): We could probably use info about file size to do this beter in the future
        // Pre-allocate based on estimated file characteristics.
        const estimated_lines = estimated_file_size / 80;
        const estimated_matches = estimated_lines / 20;

        return Self{ .content_buffer = try allocator.alloc(u8, estimated_file_size), .line_starts = try std.ArrayList(u32).initCapacity(allocator, estimated_lines), .match_positions = try std.ArrayList(u32).initCapacity(allocator, estimated_matches), .match_line_indices = try std.ArrayList(u32).initCapacity(allocator, estimated_matches), .output_buffer = try allocator.alloc(u8, 8192), .temp_buffer = try allocator.alloc(u8, 4096), .needle_len = 0, .total_matches = 0, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.content_buffer);
        self.allocator.free(self.output_buffer);
        self.allocator.free(self.temp_buffer);
        self.line_starts.deinit();
        self.match_positions.deinit();
        self.match_line_indices.deinit();
    }

    pub fn getLineSlice(self: *const Self, line_index: usize) []const u8 {
        const start = self.line_starts.items[line_index];
        const end: usize = if (line_index + 1 < self.line_starts.items.len)
            self.line_starts.items[line_index + 1] - 1 // -1 to exclude newline character
        else
            @intCast(self.content_buffer.len);

        return self.content_buffer[start..end];
    }

    // Check if a line has any matches
    pub fn lineHasMathces(self: *const Self, line_index: u32) bool {
        for (self.match_line_indices.items) |match_line| {
            if (match_line == line_index) return true;
            if (match_line > line_index) break;
        }

        return false;
    }
};

pub const SearchOptions = struct {
    input_file: ?*const fs.File = null,
    haystack: ?[]const u8 = null,
    needle: []const u8,
    results: *std.ArrayList(FoundItem),
    matches: ?*std.ArrayList(Match) = null,
    regex_path: bool = false,
    comptime buf_size: usize = 4096,
    allocator: std.mem.Allocator,
};

// TODO: Return an error here if both haystack and input_file are null.
pub fn search(options: SearchOptions) !void {
    const buffer = try options.allocator.alloc(u8, options.buf_size);
    defer options.allocator.free(buffer);

    // TODO: For using regex we could pass the string as r''?
    if (options.input_file) |file| {
        const stat = try file.stat();
        const estimated_file_size = stat.size;
        var results = try SearchResults.init(options.allocator, estimated_file_size);

        const out = std.io.getStdOut();
        var buf_writer = std.io.bufferedWriter(out.writer());
        const writer = buf_writer.writer();

        // try searchFileOrStdIn(file, options.needle, options.allocator);
        try searchFile(file, options.needle, &results);
        try writeColorizedOutput(results.content_buffer, results.line_starts.items, results.match_positions.items, options.needle, Color.green, writer);
        try buf_writer.flush();
    } else if (options.haystack) |haystack| {
        if (options.regex_path) {
            if (options.matches) |matches| {
                std.debug.print("Searching text with regex\n", .{});
                try searchTextRegex(haystack, options.needle, matches, options.allocator);
            } else {
                unreachable;
            }
        } else {
            try searchText(haystack, options.needle, buffer);
        }
    }
}

// TODO: We will want to make the color configurable here.
fn searchFileOrStdIn(input_file: *const std.fs.File, needle: []const u8, allocator: std.mem.Allocator) !void {
    var full_buffer = std.ArrayList(u8).init(allocator);
    defer full_buffer.deinit();

    const chunk_size = 64 * 1024;
    var chunk = try allocator.alloc(u8, chunk_size);
    defer allocator.free(chunk);

    while (true) {
        const bytes_read = try input_file.read(chunk);
        if (bytes_read == 0) break;
        try full_buffer.appendSlice(chunk[0..bytes_read]);
    }

    const data = full_buffer.items;

    // SoA collections (reserve capacity assuming avg line ~80 bytes, matches rare)
    var line_starts = try std.ArrayList(usize).initCapacity(allocator, @max(1, data.len / 80));
    defer line_starts.deinit();
    try line_starts.append(0);

    var match_positions = try std.ArrayList(usize).initCapacity(allocator, @max(1, data.len / 1000));
    defer match_positions.deinit();

    // // Single pass for lines (O(n), avoid appending if at end)
    var i: usize = 0;
    while (i < data.len) : (i += 1) {
        if (data[i] == '\n') {
            if (i + 1 < data.len) {
                try line_starts.append(i + 1);
            }
        }
    }

    var search_pos: usize = 0;
    while (std.mem.indexOfPos(u8, data, search_pos, needle)) |pos| {
        try match_positions.append(pos);
        search_pos = pos + needle.len;
    }

    // output matches
    const out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(out.writer());
    var writer = buf_writer.writer();

    try writeColorizedOutput(data, line_starts.items, match_positions.items, needle, .green, &writer);

    try buf_writer.flush();
}

pub fn searchFile(file: *const std.fs.File, needle: []const u8, results: *SearchResults) !void {
    // Read entire file in large chunks
    const chunk_size = 64 * 1024; // 64KB chunks for optimal I/O (on most systems)
    var bytes_read: usize = 0;

    while (true) {
        const remaining = results.content_buffer.len - bytes_read;
        if (remaining == 0) break;

        const to_read = @min(chunk_size, remaining);
        const actual_read = try file.read(results.content_buffer[bytes_read .. bytes_read + to_read]);
        if (actual_read == 0) break;

        bytes_read += actual_read;
    }

    // Resize content buffer to actual file size
    results.content_buffer = results.content_buffer[0..bytes_read];
    results.needle_len = @intCast(needle.len);

    // Single-pass processing: find lines and matches simultaneously
    try findLinesAndMatches(results, needle);
}

fn findLinesAndMatches(results: *SearchResults, needle: []const u8) !void {
    const data = results.content_buffer;
    var pos: usize = 0;
    var line_num: u32 = 0;
    var line_start: u32 = 0;

    // Always add the first line
    try results.line_starts.append(0);

    while (pos < data.len) {
        const char = data[pos];

        // Check fo rnewline to track line bounderies
        if (char == '\n') {
            line_num += 1;
            line_start = @intCast(pos + 1);
            if (line_start < data.len) {
                try results.line_starts.append(line_start);
            }
        }

        // Check for needle match at current position
        if (pos + needle.len <= data.len and std.mem.eql(u8, data[pos .. pos + needle.len], needle)) {
            try results.match_positions.append(@intCast(pos));
            try results.match_line_indices.append(line_num);
            results.total_matches += 1;

            // Skip ahead to avoid overlapping matches
            pos += needle.len;
            continue;
        }

        pos += 1;
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
fn searchText(haystack: []const u8, needle: []const u8, buffer: []u8) !void {
    var haystack_lines = std.mem.splitSequence(u8, haystack, "\n");
    var line_number: usize = 1;
    var index_of: usize = undefined;
    const out = std.io.getStdOut();
    var buf_writer = std.io.bufferedWriter(out.writer());
    var writer = buf_writer.writer();

    while (haystack_lines.next()) |line| : (line_number += 1) {
        index_of = std.mem.indexOf(u8, line, needle) orelse continue;
        try writeOutput(line, needle, &writer, buffer);
    }
    try buf_writer.flush();
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
