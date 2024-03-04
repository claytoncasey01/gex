const std = @import("std");
const ArrayList = std.ArrayList;
const FoundItem = @import("types.zig").FoundItem;

pub const Color = enum(u8) {
    reset,
    red,
    green,

    pub fn getCode(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
        };
    }
};

// NOTE: This works but it may not be the most efficient way to do this.
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

test "colorizeWord" {
    const allocator = std.testing.allocator;
    const str = "Hello, world!";
    const word = "world";
    const colorized = try colorizeWord(str, Color.green, word, allocator);
    defer allocator.free(colorized);
    try std.testing.expectEqualStrings("Hello, \x1b[32mworld\x1b[0m!", colorized);
}

// Options for how the output is handled.
// TODO: Look into possibly handling the colorize here instead of in the search functions.
pub const OutputOptions = struct { line_number: bool = false, file_path: ?[]const u8, delimiter: []const u8 = "\n", color: Color = Color.green };

// TODO: Currently this only writes the output to the console in the same way
// as we were. This needs to handle various arguments for writting in different ways
// for example, normal strings or structured data.
pub fn writeOutput(found_items: *ArrayList(FoundItem), search_for: []const u8, options: OutputOptions) !void {
    const allocator = found_items.allocator;
    const out = std.io.getStdOut();
    var buf = std.io.bufferedWriter(out.writer());
    var w = buf.writer();

    if (options.line_number) {
        for (found_items.items) |item| {
            try w.print("{d} {s}{s}", .{ item.line_number, try colorizeWord(item.line, search_for, options.color, allocator), options.delimiter });
            try buf.flush();
        }
    } else {
        for (found_items.items) |item| {
            try w.print("{s}{s}", .{ try colorizeWord(item.line, search_for, options.color, allocator), options.delimiter });
            try buf.flush();
        }
    }
}
