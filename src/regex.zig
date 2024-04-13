const std = @import("std");
const Allocator = std.mem.Allocator;
const toCString = @import("util.zig").toCString;
const Color = @import("output.zig").Color;
const colorizeWord = @import("output.zig").colorizeWord;
const c = @cImport({
    @cInclude("regex.h");
    @cInclude("regex_tiny.h");
});

pub const WordPosition = struct {
    start: usize,
    end: usize,
};

pub const Match = struct {
    const Self = @This();

    allocator: Allocator,
    slice: []const u8,
    line_number: usize,
    position: WordPosition,

    pub fn init(slice: []const u8, line_number: usize, position: WordPosition, allocator: Allocator) !Self {
        const slice_copy = try allocator.dupe(u8, slice);
        return Self{ .slice = slice_copy, .line_number = line_number, .position = position, .allocator = allocator };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.slice);
    }
};

pub const Regex = struct {
    const Self = @This();

    inner: *c.regex_t,
    allocator: Allocator,

    pub fn compile(pattern: []const u8, allocator: Allocator) !Self {
        const inner = c.alloc_regex_t().?;
        const c_pattern = try toCString(pattern, allocator);
        defer allocator.free(c_pattern);

        if (c.regcomp(inner, c_pattern, c.REG_NEWLINE | c.REG_EXTENDED) != 0) {
            return error.compile;
        }

        return Self{ .inner = inner, .allocator = allocator };
    }

    pub fn deinit(self: Self) void {
        c.free_regex_t(self.inner);
    }

    // TODO: Fix this, should take []const u8 and convert to CString
    fn is_match(self: Self, input: [:0]const u8) bool {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        return c.regexec(self.inner, input, match_size, &pmatch, 0) == 0;
    }

    pub fn exec(self: Self, input: []const u8) !WordPosition {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        const c_string = try toCString(input, self.allocator);
        defer self.allocator.free(c_string);

        const string = input;

        while (string.len > 0) {
            if (0 != c.regexec(self.inner, c_string, match_size, &pmatch, 0)) {
                break;
            }

            const start = @as(usize, @intCast(pmatch[0].rm_so));
            const end = @as(usize, @intCast(pmatch[0].rm_eo));

            if (end > string.len) {
                break;
            }

            return WordPosition{ .start = start, .end = end };

            // string = string[end..];
        }

        return WordPosition{ .start = 0, .end = 0 };
    }
};

pub fn testPrintMatches(matches: *std.ArrayList(Match)) void {
    for (matches.items) |match| {
        std.debug.print("{d} Match Line: {s}\n", .{ match.line_number, match.slice });
        match.deinit();
    }
}

// test "exec function - single match" {
//     const allocator = std.testing.allocator;
//     const matches = try std.ArrayList(Match).init(allocator);
//     const pattern = try Regex.compile("Gatsby");
//     defer pattern.deinit();
//
//     const input = "The Great Gatsby";
//     try pattern.exec(input, &matches);
//     defer allocator.free(matches);
//
//     try std.testing.expectEqual(matches.len, 2);
//     try std.testing.expectEqual(matches[0].slice, "Gatsby");
//     try std.testing.expectEqual(matches[0].start, 1);
//     try std.testing.expectEqual(matches[0].end, 16);
// }
