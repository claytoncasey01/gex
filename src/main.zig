const std = @import("std");
const clap = @import("deps/zig-clap/clap.zig");
const FoundItem = @import("types.zig").FoundItem;
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;
const OutputOptions = @import("output.zig").OutputOptions;
const writeOutput = @import("output.zig").writeOutput;
const search = @import("input.zig").search;
const SearchOptions = @import("input.zig").SearchOptions;
const Regex = @import("regex.zig").Regex;
const Match = @import("regex.zig").Match;
const WordPosition = @import("regex.zig").WordPosition;
const testPrintMatches = @import("regex.zig").testPrintMatches;
const io = std.io;
const toCString = @import("util.zig").toCString;

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
        \\-R, --regex Test the regex, print the matches, and exit.
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

    var matches = std.ArrayList(Match).init(allocator);
    defer matches.deinit();

    var color: Color = Color.green;
    const use_regex = parsed_args.args.regex != 0;

    // A color was passed, so pull it out
    if (parsed_args.args.color.len > 0) {
        // If an invalid color is passed, just default to green
        color = std.meta.stringToEnum(Color, parsed_args.args.color[0]) orelse Color.green;
    }

    if (parsed_args.positionals.len == 2) {
        // Pull out our positional arguments
        const needle = parsed_args.positionals[0];
        const haystack = parsed_args.positionals[1];
        var needs_free = false;

        // In this case we most likely are dealing with a file or directory, just assume so for now
        if (std.fs.cwd().statFile(haystack)) |stat| {
            switch (stat.kind) {
                .directory => std.debug.print("{s} is a directory\n", .{haystack}),
                .file => {
                    needs_free = true;
                    // Get the handle for the file to be searched
                    const file = try std.fs.cwd().openFile(haystack, .{ .mode = .read_only });
                    defer file.close();

                    const options = SearchOptions{ .input_file = &file, .needle = needle, .results = &found, .regex_path = use_regex, .matches = &matches, .allocator = allocator };
                    try search(options);
                },
                else => std.debug.print("{s} is not a file or directory\n", .{haystack}),
            }
        } else |err| switch (err) {
            error.FileNotFound => {
                const options = SearchOptions{ .matches = &matches, .regex_path = use_regex, .haystack = haystack, .needle = needle, .results = &found, .allocator = allocator };
                try search(options);
            },
            else => std.debug.print("An error occured", .{}),
        }

        // TODO: This is a bit of a hack, but it works for now
        try writeOutput(&found, needle, OutputOptions{ .matches = &matches, .regex_path = use_regex, .line_number = true, .file_path = null, .needs_free = needs_free, .color = color }, allocator);
    } else if (parsed_args.positionals.len == 1) { // Assume we are getting piped input
        const needle = parsed_args.positionals[0];
        // This is esentially the same as searchFile, but we are reading from stdin
        // could probably be refactored to both use the same function.
        const stdin = std.io.getStdIn();
        const options = SearchOptions{ .matches = &matches, .regex_path = use_regex, .input_file = &stdin, .needle = needle, .results = &found, .allocator = allocator };

        try search(options);

        try writeOutput(&found, needle, OutputOptions{ .matches = &matches, .regex_path = use_regex, .line_number = false, .file_path = null, .needs_free = true, .color = color }, allocator);
    } else if (parsed_args.args.help != 0) {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    } else {
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        // Could probably handle this better just by writing to stderr ourselves.
        try diag.report(std.io.getStdErr().writer(), error.NotEnoughArguments);
    }
}

test {
    std.testing.refAllDecls(@This());
}
