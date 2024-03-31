const std = @import("std");
const c = @cImport({
    @cInclude("regex.h");
    @cInclude("regex_tiny.h");
});

pub const Match = struct {
    slice: []const u8,
    start: usize,
    end: usize,
};

pub const Regex = struct {
    inner: *c.regex_t,

    fn compile(pattern: [:0]const u8) !Regex {
        const inner = c.alloc_regex_t().?;
        if (c.regcomp(inner, pattern, c.REG_NEWLINE | c.REG_EXTENDED) != 0) {
            return error.compile;
        }

        return .{
            .inner = inner,
        };
    }

    fn deinit(self: Regex) void {
        c.free_regex_t(self.inner);
    }

    fn is_match(self: Regex, input: [:0]const u8) bool {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        return c.regexec(self.inner, input, match_size, &pmatch, 0) == 0;
    }

    fn exec(self: Regex, input: [:0]const u8, matches: *std.ArrayList(Match)) !void {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        var string = input;

        while (true) {
            if (0 != c.regexec(self.inner, string, match_size, &pmatch, 0)) {
                break;
            }

            const start = @as(usize, @intCast(pmatch[0].rm_so));
            const end = @as(usize, @intCast(pmatch[0].rm_eo));
            const slice = string[start..end];

            try matches.append(Match{
                .slice = slice,
                .start = start,
                .end = end,
            });

            string = string[end..];
        }
    }
};

test "exec function - single match" {
    const allocator = std.testing.allocator;
    const matches = try std.ArrayList(Match).init(allocator);
    const pattern = try Regex.compile("Gatsby");
    defer pattern.deinit();

    const input = "The Great Gatsby";
    try pattern.exec(input, &matches);
    defer allocator.free(matches);

    try std.testing.expectEqual(matches.len, 2);
    try std.testing.expectEqual(matches[0].slice, "Gatsby");
    try std.testing.expectEqual(matches[0].start, 1);
    try std.testing.expectEqual(matches[0].end, 16);
}
