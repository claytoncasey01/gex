const std = @import("std");
const Allocator = std.mem.Allocator;
const toCString = @import("util.zig").toCString;
const Color = @import("output.zig").Color;
const colorizeWord = @import("output.zig").colorizeWord;
const c = @cImport({
    @cInclude("regex.h");
    @cInclude("regex_tiny.h");
});

const WordPosition = struct {
    start: usize,
    end: usize,
};

pub const Match = struct {
    const Self = @This();

    allocator: Allocator,
    slice: []const u8,
    line_number: usize,
    indexes: std.ArrayList(WordPosition),

    pub fn init(slice: []const u8, line_number: usize, allocator: Allocator) Self {
        return Self{ .slice = slice, .line_number = line_number, .indexes = std.ArrayList(WordPosition).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: Self) void {
        self.allocator.free(self.slice);
        self.indexes.deinit();
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

    pub fn exec(self: Self, input: []const u8, matches: *std.ArrayList(Match)) !void {
        const match_size = 1;
        var pmatch: [match_size]c.regmatch_t = undefined;

        const c_string = try toCString(input, self.allocator);
        defer self.allocator.free(c_string);

        // Preprocess the input string to store the line bounderies
        var line_starts = std.ArrayList(usize).init(self.allocator);
        defer line_starts.deinit();

        var start_line: usize = 0;
        while (start_line < input.len) {
            try line_starts.append(start_line);
            const line_end = std.mem.indexOfScalarPos(u8, input, start_line, '\n');
            start_line = if (line_end) |end| end + 1 else input.len;
        }

        var string = c_string;
        var line_index: usize = 0;

        // Map to store the indexes of each Match struct by line number
        var match_map = std.AutoHashMap(usize, usize).init(self.allocator);
        defer match_map.deinit();

        while (string.len > 0) {
            if (0 != c.regexec(self.inner, string, match_size, &pmatch, 0)) {
                break;
            }

            const start = @as(usize, @intCast(pmatch[0].rm_so));
            const end = @as(usize, @intCast(pmatch[0].rm_eo));

            if (end > string.len) {
                break;
            }

            // Find the line number and line slice for the match
            while (line_index + 1 < line_starts.items.len and line_starts.items[line_index + 1] < start) {
                line_index += 1;
            }

            const line_number = line_index + 1;
            const line_start = line_starts.items[line_index];
            const line_end = if (line_index + 1 < line_starts.items.len) line_starts.items[line_index + 1] - 1 else input.len;

            const line_slice = input[line_start..line_end];

            if (match_map.get(line_number)) |index| {
                try matches.items[index].indexes.append(.{ .start = start, .end = end });
            } else {
                const line_copy = try self.allocator.dupe(u8, line_slice);
                var match = Match.init(line_copy, line_number, self.allocator);
                try match.indexes.append(.{ .start = start, .end = end });
                try matches.append(match);

                // store the index of the new Match struct in the map
                try match_map.put(line_number, matches.items.len - 1);
            }

            string = string[end..];
        }
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
