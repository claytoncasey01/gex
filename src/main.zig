const std = @import("std");
const args = @import("input/args.zig");
const FoundItem = struct {
    line_number: usize,
    line: []const u8,
};

pub fn main() !void {
    // NOTE: std.os.args does not work on windows or wasi
    const cliArgs = std.os.argv;
    const parsedArgs = args.parseArgs(cliArgs);
    const allocator = std.heap.ArenaAllocator;
    var found = std.ArrayList(FoundItem).init(allocator);
    defer found.deinit();

    try search(parsedArgs.text, parsedArgs.search_for, &found);
    // TODO: This is just for debugging purposes, need to implement actual output to sdtout
    for (found.items) |item| {
        std.debug.print("{d} {s}\n", .{ item.line_number, item.line });
    }
}

// Takes a string to be searched and a string to search for. It will return
// a modified version of the to_seach with all the instances of search_for highlighted
// NOTE: It might be useful to update this to also return some statistics about the search,
// like the number of matches, the indexes of the matches, etc.
fn search(to_search: []const u8, search_for: []const u8, found: *std.ArrayList(FoundItem)) !void {
    var to_search_lines = std.mem.splitSequence(u8, to_search, "\n");
    var cursor: usize = 1;
    var indexOf: usize = undefined;

    while (to_search_lines.next()) |line| {
        indexOf = std.mem.indexOf(u8, line, search_for) orelse continue;

        if (indexOf > 0) {
            try found.append(FoundItem{ .line_number = cursor, .line = line });
            cursor += 1;
        }
    }
}
