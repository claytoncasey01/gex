const std = @import("std");
const args = @import("args.zig");
const FoundItem = @import("types.zig").FoundItem;
const fileHandler = @import("file.zig");
const colorizeWord = @import("output.zig").colorizeWord;
const Color = @import("output.zig").Color;
const OutputOptions = @import("output.zig").OutputOptions;
const writeOutput = @import("output.zig").writeOutput;

pub fn main() !void {
    // NOTE: std.os.args does not work on windows or wasi
    const cli_args = std.os.argv;
    const parsed_args = args.parseArgs(cli_args);
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var found = std.ArrayList(FoundItem).init(allocator);
    defer found.deinit();

    // In this case we most likely are dealing with a file or directory, just assume so for now
    if (std.fs.cwd().statFile(parsed_args.text)) |stat| {
        switch (stat.kind) {
            .directory => std.debug.print("{s} is a directory\n", .{parsed_args.text}),
            .file => try fileHandler.searchFile(parsed_args.text, parsed_args.search_for, &found),
            else => std.debug.print("{s} is not a file or directory\n", .{parsed_args.text}),
        }
    } else |err| switch (err) {
        error.FileNotFound => try search(parsed_args.text, parsed_args.search_for, &found),
        else => std.debug.print("An error occured", .{}),
    }
    try writeOutput(&found, parsed_args.search_for, OutputOptions{ .line_number = false, .file_path = null });
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
