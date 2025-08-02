const std = @import("std");
const GenericWriter = std.io.GenericWriter;
const ArrayList = std.ArrayList;
const FoundItem = @import("types.zig").FoundItem;
const Match = @import("regex.zig").Match;
const SearchResults = @import("input.zig").SearchResults;

pub const Color = enum(u8) {
    reset,
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,
    blackBright,
    redBright,
    greenBright,
    yellowBright,
    blueBright,
    magentaBright,
    cyanBright,
    whiteBright,
    // Background Colors
    bgBlack,
    bgRed,
    bgGreen,
    bgYellow,
    bgBlue,
    bgMagenta,
    bgCyan,
    bgWhite,
    bgBlackBright,
    bgRedBright,
    bgGreenBright,
    bgYellowBright,
    bgBlueBright,
    bgMagentaBright,
    bgCyanBright,
    bgWhiteBright,

    pub fn getCode(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .blackBright => "\x1b[90m",
            .redBright => "\x1b[91m",
            .greenBright => "\x1b[92m",
            .yellowBright => "\x1b[93m",
            .blueBright => "\x1b[94m",
            .magentaBright => "\x1b[95m",
            .cyanBright => "\x1b[96m",
            .whiteBright => "\x1b[97m",
            .bgBlack => "\x1b[40m",
            .bgRed => "\x1b[41m",
            .bgGreen => "\x1b[42m",
            .bgYellow => "\x1b[43m",
            .bgBlue => "\x1b[44m",
            .bgMagenta => "\x1b[45m",
            .bgCyan => "\x1b[46m",
            .bgWhite => "\x1b[47m",
            .bgBlackBright => "\x1b[100m",
            .bgRedBright => "\x1b[101m",
            .bgGreenBright => "\x1b[102m",
            .bgYellowBright => "\x1b[103m",
            .bgBlueBright => "\x1b[104m",
            .bgMagentaBright => "\x1b[105m",
            .bgCyanBright => "\x1b[106m",
            .bgWhiteBright => "\x1b[107m",
        };
    }
};

// NOTE: This works but it may not be the most efficient way to do this.
// with regex we have the start and end index of a match, so we shouldn't need
// to do a search here anymore.
pub fn colorizeWord(str: []const u8, word: []const u8, color: Color, allocator: std.mem.Allocator) ![]const u8 {
    const color_code = color.getCode();
    const reset_code = Color.reset.getCode();

    // Calculate the total occurences of `word` in `str`
    var occurrences: usize = 0;
    var i: usize = 0;
    while (i < str.len) : (i += 1) {
        if (std.mem.startsWith(u8, str[i..], word)) {
            occurrences += 1;
            i += word.len - 1;
        }
    }

    // Calculate the length and allocate memory for the final colorized string
    const extra_len_per_occurrence = color_code.len + reset_code.len;
    const result_string_len = str.len + (extra_len_per_occurrence * occurrences);
    var result_string = try allocator.alloc(u8, result_string_len);

    // Construct the `result_string` with colorized words
    var result_index: usize = 0;
    i = 0;
    while (i < str.len) {
        if (std.mem.startsWith(u8, str[i..], word)) {
            std.mem.copyForwards(u8, result_string[result_index..][0..color_code.len], color_code);
            result_index += color_code.len;
            std.mem.copyForwards(u8, result_string[result_index..][0..word.len], word);
            result_index += word.len;
            std.mem.copyForwards(u8, result_string[result_index..][0..reset_code.len], reset_code);
            result_index += reset_code.len;
            i += word.len;
        } else {
            result_string[result_index] = str[i];
            result_index += 1;
            i += 1;
        }
    }

    return result_string;
}

pub fn colorizeWordNoAlloc(str: []const u8, word: []const u8, color: Color, buffer: []u8) ![]const u8 {
    const color_code = color.getCode();
    const reset_code = Color.reset.getCode();
    const extra_len_per_occurrence = color_code.len + reset_code.len;

    if (word.len == 0) return str;

    // Calculate the total occurences of `word` in `str`
    var occurrences: usize = 0;
    var i: usize = 0;
    while (i < str.len) {
        if (std.mem.startsWith(u8, str[i..], word)) {
            occurrences += 1;
            i += word.len;
        } else {
            i += 1;
        }
    }

    if (occurrences == 0) return str;

    // Calculate the length and allocate memory for the final colorized string
    const result_string_len = str.len + (extra_len_per_occurrence * occurrences);

    // Construct the `result_string` with colorized words
    var result_index: usize = 0;
    i = 0;
    var current_str_ptr = str;

    while (i < str.len) {
        if (std.mem.startsWith(u8, current_str_ptr, word)) {
            std.mem.copyForwards(u8, buffer[result_index..][0..color_code.len], color_code);
            result_index += color_code.len;
            std.mem.copyForwards(u8, buffer[result_index..][0..word.len], word);
            result_index += word.len;
            std.mem.copyForwards(u8, buffer[result_index..][0..reset_code.len], reset_code);
            result_index += reset_code.len;
            i += word.len;
            current_str_ptr = str[i..];
        } else {
            buffer[result_index] = current_str_ptr[0];
            result_index += 1;
            i += 1;
            current_str_ptr = str[i..];
        }
    }

    return buffer[0..result_string_len];
}

test "colorizeWord" {
    const allocator = std.testing.allocator;
    const str = "Hello, world!";
    const word = "world";
    const colorized = try colorizeWord(str, word, Color.green, allocator);
    defer allocator.free(colorized);
    try std.testing.expectEqualStrings("Hello, \x1b[32mworld\x1b[0m!", colorized);
}

// Options for how the output is handled.
pub const OutputOptions = struct { matches: *ArrayList(Match), regex_path: bool = false, line_number: bool = false, file_path: ?[]const u8, needs_free: bool, delimiter: []const u8 = "\n", color: Color };

// TODO: Currently this only writes the output to the console in the same way
// as we were. This needs to handle various arguments for writting in different ways
// for example, normal strings or structured data.
pub fn writeOutput(found_items: *ArrayList(FoundItem), needle: []const u8, options: OutputOptions, allocator: std.mem.Allocator) !void {
    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());
    var w = buf.writer();

    // Handle the regex path seperatly for now
    if (options.regex_path) {
        for (options.matches.items) |match| {
            defer match.deinit();
            const colorizedWord = try colorizeWord(match.slice, needle, options.color, allocator);
            try w.print("{d} {s}{s}", .{ match.line_number, colorizedWord, options.delimiter });
            try buf.flush();
            allocator.free(colorizedWord); // Colorize allocates memeory for the new string so we need to free it.
        }
    } else {
        if (options.line_number) {
            for (found_items.items) |item| {
                const colorizedWord = try colorizeWord(item.line, needle, options.color, allocator);
                try w.print("{d} {s}{s}", .{ item.line_number, colorizedWord, options.delimiter });
                try buf.flush();
                allocator.free(colorizedWord); // Colorize allocates memeory for the new string so we need to free it.
                if (options.needs_free) allocator.free(item.line); // If we are reading from a file we need to free the line since we allocate it.
            }
        } else {
            for (found_items.items) |item| {
                const colorizedWord = try colorizeWord(item.line, needle, options.color, allocator);
                try w.print("{s}{s}", .{ colorizedWord, options.delimiter });
                try buf.flush();
                allocator.free(colorizedWord); // Colorize allocates memeory for the new string so we need to free it.
                if (options.needs_free) allocator.free(item.line); // If we are reading from a file we need to free the line since we allocate it.

            }
        }
    }
}

// TODO: Currently this only writes the output to the console in the same way
// as we were. This needs to handle various arguments for writting in different ways
// for example, normal strings or structured data.
// We also should have a specific type for w but they way writers work makes this hard, figure it out.
pub fn writeOutputNew(line: []const u8, needle: []const u8, w: anytype, buffer: []u8) !void {
    // Handle the regex path seperatly for now
    if (false) {
        const colorizedWord = try colorizeWordNoAlloc(line, needle, Color.green, buffer);
        try w.print("{d} {s}{s}", .{ 0, colorizedWord, "\n" });
    } else {
        const colorizedWord = try colorizeWordNoAlloc(line, needle, Color.green, buffer);
        try w.print("{s}{s}", .{ colorizedWord, "\n" });
    }
}

pub fn writeColorizedOutput(
    full_buffer: []const u8,
    line_starts: []const u32,
    match_positions: []const u32,
    needle: []const u8,
    color: Color,
    writer: anytype,
) !void {
    const color_code = color.getCode();
    const reset_code = Color.reset.getCode();

    // Early exit: if not matches exist at all, don't do any work
    if (match_positions.len == 0) return;

    // Assume match_positions sorted
    var match_idx: usize = 0;
    for (line_starts, 0..) |line_start, idx| {
        const line_end = if (idx + 1 < line_starts.len)
            line_starts[idx + 1]
        else
            full_buffer.len;

        var temp_match_idx = match_idx;
        var line_has_matches = false;

        while (temp_match_idx < match_positions.len) {
            const match_pos = match_positions[temp_match_idx];

            // If this match is beyond the current line, we can stop scanning
            if (match_pos >= line_end) break;

            // If this match is within the current line, we found at least one match
            if (match_pos >= line_start) {
                line_has_matches = true;
                break;
            }

            temp_match_idx += 1;
        }

        // If the line has no matches, skip it.
        if (!line_has_matches) {
            // Fast-forward match_idx past any matches that were before this line.
            while (match_idx < match_positions.len and match_positions[match_idx] < line_start) {
                match_idx += 1;
            }
            continue;
        }

        // Peek: Skip if no matches in this line
        if (match_idx >= match_positions.len or
            match_positions[match_idx] < line_start or
            match_positions[match_idx] >= line_end) continue;

        // Strip trailing \n if present
        const actual_end = if (line_end > line_start and full_buffer[line_end - 1] == '\n')
            line_end - 1
        else
            line_end;

        const line_content = full_buffer[line_start..actual_end];

        // Pre-calculate how much work we need to do
        // by counting matches in this line.
        var matches_in_line: usize = 0;
        var first_match_idx = match_idx;

        // Advance our match_idx to the first match that's actually in this line
        while (match_idx < match_positions.len and match_positions[match_idx] < line_start) {
            match_idx += 1;
        }
        first_match_idx = match_idx;

        // Count how many matches are in this line
        while (match_idx < match_positions.len and match_positions[match_idx] < line_end) {
            matches_in_line += 1;
            match_idx += 1;
        }

        // Handle wiritng matches differently depending on if we have a single match
        // in the line or multiple.
        if (matches_in_line == 1) {
            try writeSingleMatchLine(line_content, line_start, match_positions[first_match_idx], needle, color_code, reset_code, writer);
        } else {
            try writeMultiMatchLine(line_content, line_start, match_positions[first_match_idx .. first_match_idx + matches_in_line], needle, color_code, reset_code, writer);
        }
    }
}

// Writes everything as 3 consecutive chunks to minimize sys calls
fn writeSingleMatchLine(line_content: []const u8, line_start: u32, match_position: u32, needle: []const u8, color_code: []const u8, reset_code: []const u8, writer: anytype) !void {
    const match_offset = match_position - line_start;

    // Chunk 1: Text before match
    if (match_offset > 0) {
        try writer.writeAll(line_content[0..match_offset]);
    }

    // Chunk 2: Colorized match
    try writer.writeAll(color_code);
    try writer.writeAll(line_content[match_offset .. match_offset + needle.len]);
    try writer.writeAll(reset_code);

    // Chunk 3: Text after the match + newline
    const after_match = match_offset + needle.len;
    if (after_match < line_content.len) {
        try writer.writeAll(line_content[after_match..]);
    }
    try writer.writeByte('\n');
}

// Batch operations to reduce syscalls
// NOTE(casey): We could use a pre-allocated buffer to batch multiple lines, maybe do this later
fn writeMultiMatchLine(line_content: []const u8, line_start: u32, match_positions: []const u32, needle: []const u8, color_code: []const u8, reset_code: []const u8, writer: anytype) !void {
    var pos: usize = 0;
    // Process each match in sequence, building up the colorized line
    for (match_positions) |match_pos| {
        const match_offset = match_pos - line_start;

        // make sure the match is actually within this line
        if (match_offset >= line_content.len) continue;

        // Write text before this match
        if (match_offset > pos) {
            try writer.writeAll(line_content[pos..match_offset]);
        }

        // Write colorized match
        try writer.writeAll(color_code);
        try writer.writeAll(line_content[match_offset .. match_offset + needle.len]);
        try writer.writeAll(reset_code);

        pos = match_offset + needle.len;
    }

    // Write any remaining text after the last match
    if (pos < line_content.len) {
        try writer.writeAll(line_content[pos..]);
    }

    try writer.writeByte('\n');
}
