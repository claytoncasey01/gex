const std = @import("std");

pub const Args = struct { verbose: bool, help: bool, text: []const u8, search_for: []const u8 };
const PossibleArgs = enum { @"-v", @"--verbose", @"-h", @"--help" };

pub fn parseArgs(args: *std.process.ArgIterator) Args {
    var parsed_args = Args{
        .verbose = false,
        .help = false,
        .text = "",
        .search_for = "",
    };

    if (args.skip()) {
        var i: usize = 1;
        while (args.next()) |arg| {
            // We know the first 2 args should be the search pattern and the text to search in
            // if we are past those, parse the rest of the args.
            // TODO: Need to add support for handling files as the second argument.
            if (i > 2) {
                const args_enum = std.meta.stringToEnum(PossibleArgs, arg) orelse break;
                switch (args_enum) {
                    .@"-v" => parsed_args.verbose = true,
                    .@"-h" => parsed_args.help = true,
                    else => std.debug.print("Argument: {s}\n", .{arg}),
                }
            } else if (i == 1) {
                parsed_args.search_for = arg;
                i += 1;
            } else if (i == 2) {
                parsed_args.text = arg;
                i += 1;
            }
        }
    } else {
        std.debug.print("Debug Error: No args were given", .{});
    }

    return parsed_args;
}
