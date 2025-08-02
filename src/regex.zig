const std = @import("std");
const Allocator = std.mem.Allocator;
const toCString = @import("util.zig").toCString;
const Color = @import("output.zig").Color;
const colorizeWord = @import("output.zig").colorizeWord;
const c = @cImport({
    @cInclude("regex_tiny.h");
});

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

    pub fn exec() !void {}
};
