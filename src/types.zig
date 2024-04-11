// TODO This will be replaced my Match in regex.zig
pub const FoundItem = struct {
    index: usize,
    line_number: usize,
    line: []const u8,
};

// Errors
const InvalidArgumentsError = error{
    NotEnoughArguments,
};
