const std = @import("std");

pub const Args = struct { verbose: bool, help: bool, text: []const u8, search_for: []const u8 };
const PossibleArgs = enum { @"-v", @"--verbose", @"-h", @"--help" };

pub fn parseArgs(args: [][*:0]u8) Args {
    var parsed_args = Args{
        .verbose = false,
        .help = false,
        .text = "",
        .search_for = "",
    };

    if (args.len > 2) {
        // Pull out the search_for and text args right away, any additonal flags will come after these 2
        parsed_args.search_for = std.mem.span(args[1]);
        parsed_args.text = std.mem.span(args[2]);

        for (args[3..]) |arg| {
            const args_enum = std.meta.stringToEnum(PossibleArgs, std.mem.span(arg)) orelse break;
            switch (args_enum) {
                .@"-v", .@"--verbose" => parsed_args.verbose = true,
                .@"-h", .@"--help" => parsed_args.help = true,
            }
        }
    } else {
        std.debug.print("Debug Error: Incorrect number of args {d} given, expected at least 2", .{args.len - 1});
    }

    return parsed_args;
}
