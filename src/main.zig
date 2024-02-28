const std = @import("std");
const args = @import("input/args.zig");
const FoundItem = @import("shared/types.zig").FoundItem;
const fileHandler = @import("input/file.zig");
const formatter = @import("output/formatter.zig");

pub fn main() !void {
    // NOTE: std.os.args does not work on windows or wasi
    const cliArgs = std.os.argv;
    const parsedArgs = args.parseArgs(cliArgs);
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    // defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    var found = std.ArrayList(FoundItem).init(allocator);
    defer found.deinit();

    // In this case we most likely are dealing with a file or directory, just assume so for now
    if (std.fs.cwd().statFile(parsedArgs.text)) |stat| {
        switch (stat.kind) {
            .directory => std.debug.print("{s} is a directory\n", .{parsedArgs.text}),
            .file => try fileHandler.search_file(parsedArgs.text, parsedArgs.search_for, &found),
            else => std.debug.print("{s} is not a file or directory\n", .{parsedArgs.text}),
        }
    } else |err| switch (err) {
        error.FileNotFound => try search(parsedArgs.text, parsedArgs.search_for, &found),
        else => std.debug.print("An error occured", .{}),
    }
    // TODO: This is just for debugging purposes, need to implement actual output to sdtout
    for (found.items) |item| {
        std.debug.print("{d} {s} {d}\n", .{ item.line_number, item.line, item.index });
    }
}

// Takes a string to be searched and a string to search for. It will return
// a modified version of the to_seach with all the instances of search_for highlighted
// NOTE: It might be useful to update this to also return some statistics about the search,
// like the number of matches, the indexes of the matches, etc.
fn search(to_search: []const u8, search_for: []const u8, found: *std.ArrayList(FoundItem)) !void {
    const allocator = found.allocator;
    var to_search_lines = std.mem.splitSequence(u8, to_search, "\n");
    var cursor: usize = 1;
    var indexOf: usize = undefined;

    while (to_search_lines.next()) |line| {
        indexOf = std.mem.indexOf(u8, line, search_for) orelse continue;
        const colorized_line = try formatter.colorizeWord(line, formatter.Color.green, search_for, allocator);

        if (indexOf > 0) {
            try found.append(FoundItem{ .line_number = cursor, .line = colorized_line, .index = indexOf });
            cursor += 1;
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
