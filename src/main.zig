const std = @import("std");
const clap = @import("deps/zig-clap/clap.zig");
const FoundItem = @import("types.zig").FoundItem;
const fileHandler = @import("file.zig");
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;
const OutputOptions = @import("output.zig").OutputOptions;
const writeOutput = @import("output.zig").writeOutput;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // Setup command line arguments
    const params = comptime clap.parseParamsComptime(
        \\-h, --help Display this help and exit.
        \\-n, --line-number Prefix each line of output with the 1-based line number within its input file.
        \\-H, --with-filename Print the file name for each match.
        \\-i, --ignore-case Ignore case distinctions in both the PATTERN and the input files.
        \\-v, --invert-match Invert the sense of matching, to select non-matching lines.
        \\-w, --word-regexp Select only those lines containing matches that form whole words.
        \\-c, --color <str>... Select which color to be used when displaying the match. Defaults to green.
        \\<str> The text to search for
        \\<str> The file or text to search in
    );

    const allocator = gpa.allocator();

    // Parse line arguments
    var diag = clap.Diagnostic{};
    const parsed_args = clap.parse(clap.Help, &params, clap.parsers.default, .{ .diagnostic = &diag, .allocator = allocator }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer parsed_args.deinit();

    var found = std.ArrayList(FoundItem).init(allocator);
    defer found.deinit();

    var color: Color = Color.green;

    // A color was passed, so pull it out
    if (parsed_args.args.color.len > 0) {
        // If an invalid color is passed, just default to green
        color = std.meta.stringToEnum(Color, parsed_args.args.color[0]) orelse Color.green;
    }

    if (parsed_args.positionals.len == 2) {
        // Pull out our positional arguments
        const search_for = parsed_args.positionals[0];
        const search_in = parsed_args.positionals[0];
        var needs_free = false;

        // In this case we most likely are dealing with a file or directory, just assume so for now
        if (std.fs.cwd().statFile(search_in)) |stat| {
            switch (stat.kind) {
                .directory => std.debug.print("{s} is a directory\n", .{search_in}),
                .file => {
                    needs_free = true;
                    try fileHandler.searchFile(search_in, search_for, &found, allocator);
                },
                else => std.debug.print("{s} is not a file or directory\n", .{search_in}),
            }
        } else |err| switch (err) {
            error.FileNotFound => try search(search_in, search_for, &found),
            else => std.debug.print("An error occured", .{}),
        }

        try writeOutput(&found, search_for, OutputOptions{ .line_number = false, .file_path = null, .needs_free = needs_free, .color = color }, allocator);
    } else if (parsed_args.positionals.len == 1) { // Assume we are getting piped input
        const search_for = parsed_args.positionals[0];
        // This is esentially the same as searchFile, but we are reading from stdin
        // could probably be refactored to both use the same function.
        const in = std.io.getStdIn().reader();
        var buf = std.io.bufferedReader(in);
        var r = buf.reader();
        var piped_buf: [4096]u8 = undefined;
        var index_of: ?usize = null;
        var line_number: usize = 1;

        while (try r.readUntilDelimiterOrEof(&piped_buf, '\n')) |line| : (line_number += 1) {
            index_of = std.mem.indexOf(u8, line, search_for) orelse continue;

            if (index_of) |word_index| {
                const line_copy = try allocator.dupe(u8, line);
                try found.append(FoundItem{ .line_number = line_number, .line = line_copy, .index = word_index });
                index_of = null;
            }
        }

        try writeOutput(&found, search_for, OutputOptions{ .line_number = false, .file_path = null, .needs_free = true, .color = color }, allocator);
    } else if (parsed_args.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    } else {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        // Could probably handle this better just by writing to stderr ourselves.
        try diag.report(std.io.getStdErr().writer(), error.NotEnoughArguments);
    }
}

// Takes a string to be searched and a string to search for. It will return
// a modified version of the to_seach with all the instances of search_for highlighted
// NOTE: It might be useful to update this to also return some statistics about the search,
// like the number of matches, the indexes of the matches, etc.
fn search(to_search: []const u8, search_for: []const u8, found: *std.ArrayList(FoundItem)) !void {
    var to_search_lines = std.mem.splitSequence(u8, to_search, "\n");
    var cursor: usize = 1;
    var index_of: usize = undefined;

    while (to_search_lines.next()) |line| {
        index_of = std.mem.indexOf(u8, line, search_for) orelse continue;

        if (index_of > 0) {
            try found.append(FoundItem{ .line_number = cursor, .line = line, .index = index_of });
            cursor += 1;
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
