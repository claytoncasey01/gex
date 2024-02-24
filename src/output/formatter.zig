const std = @import("std");

pub const Color = enum(u8) {
    reset,
    red,
    green,

    pub fn getCode(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
        };
    }
};

// TODO: Make this work
pub fn colorizeWord(str: []const u8, color: Color, word: []const u8, allocator: *const std.mem.Allocator) []const u8 {

    // Calculate the length of the colorized string
    const color_code = color.getCode();
    const reset_code = Color.reset.getCode();
    const result_len = color_code.len + str.len + reset_code.len;
    const result = try allocator.alloc(u8, result_len);
    const colorized_word: []const u8 = color.getCode() + word + Color.reset.getCode();

    std.mem.replaceScalar(u8, result, word, colorized_word);

    return result;
}
