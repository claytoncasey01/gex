# gex - A Simple Grep Clone in Zig

`gex` is a small and efficient grep clone written in the Zig programming language. It provides basic text searching capabilities using both regular expressions (regex) and Zig's internal `indexOf` function from `std.mem`.

## Features

- Search for a specific pattern (needle) in a given text or file (haystack)
- Support for regular expressions using the POSIX regex C library
- Fast non-regex searching using Zig's `indexOf` function
- Colorized output with ANSI color codes
- Pipe support for searching within the output of other commands
- Comparable performance to `grep`, with only a slight overhead of around 20ms in most use cases

## Installation

To install `gex`, make sure you have Zig installed on your system. Then, follow these steps:

1.  Clone the `gex` repository:

    `git clone https://github.com/claytoncasey01/gex.git`

2.  Navigate to the `gex` directory:

    `cd gex`

3.  Build the project:

    `zig build`

4.  (Optional) Add the `gex` executable to your system's PATH for easier access.

## Usage

### Basic Usage

To search for a specific pattern (needle) in a given text or file (haystack), use the following command:

`gex [needle] [haystack]`

The `haystack` can be either input text or a file path.

### Regular Expression Support

To enable regular expression searching (experimental), add the `-R` flag to the command:

`gex [regex_pattern] [haystack] -R`

### Colorized Output

To enable colorized output using ANSI color codes, add the `-c` flag to the command:

`gex -c [needle] [haystack]`

### Piping Support

`gex` supports piping, allowing you to search within the output of other commands. For example:

`ls -l | gex zig`

This command will search for the word "zig" within the output of the `ls -l` command.

## Color Codes

`gex` supports all ANSI color codes through the `-c` flag. The available color codes are defined in the following enum:

    pub const Color = enum(u8) {
      reset,
      black,
      red,
      green,
      yellow,
      blue,
      magenta,
      cyan,
      white,
      blackBright,
      redBright,
      greenBright,
      yellowBright,
      blueBright,
      magentaBright,
      cyanBright,
      whiteBright,
      // Background Colors
      bgBlack,
      bgRed,
      bgGreen,
      bgYellow,
      bgBlue,
      bgMagenta,
      bgCyan,
      bgWhite,
      bgBlackBright,
      bgRedBright,
      bgGreenBright,
      bgYellowBright,
      bgBlueBright,
      bgMagentaBright,
      bgCyanBright,
      bgWhiteBright,
    };

## Performance

`gex` aims to provide efficient searching capabilities. In most use cases, it is only slightly slower than `grep`, with a performance overhead of around 20ms or less. We are working on performance optimizations currently to either match or beat `grep`.

## Contributing

Contributions to `gex` are welcome! If you find any bugs, have feature requests, or want to contribute improvements, please open an issue or submit a pull request on the [GitHub repository](https://github.com/claytoncasey01/gex).

## License

`gex` is open-source software licensed under the [MIT License](https://opensource.org/licenses/MIT).
