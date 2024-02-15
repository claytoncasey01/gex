const std = @import("std");

pub fn main() !void {
    const args = std.os.argv;
    var i: usize = 1;

    while (i < args.len) : (i += 1) {
        const arg = args[i];

        std.debug.print("Argument: {s}\n", .{arg});
    }
}
