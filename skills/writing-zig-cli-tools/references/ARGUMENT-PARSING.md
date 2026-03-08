# CLI Argument Parsing in Zig

## Option 1: std.process (Simple CLIs)

For tools with few arguments, use the standard library directly:

```zig
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip program name

    var verbose = false;
    var output_path: ?[]const u8 = null;
    var positionals: std.ArrayListUnmanaged([]const u8) = .{};
    defer positionals.deinit(allocator);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--verbose")) {
            verbose = true;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            output_path = args.next() orelse {
                std.debug.print("Error: --output requires a value\n", .{});
                std.process.exit(1);
            };
        } else if (std.mem.startsWith(u8, arg, "-")) {
            std.debug.print("Unknown option: {s}\n", .{arg});
            std.process.exit(1);
        } else {
            try positionals.append(allocator, arg);
        }
    }

    if (positionals.items.len == 0) {
        std.debug.print("Usage: my-cli [options] <files...>\n", .{});
        std.process.exit(1);
    }
}
```

## Option 2: zig-clap (Feature-Rich CLIs)

### Setup

```bash
zig fetch --save git+https://github.com/Hejsil/zig-clap
```

In `build.zig`:
```zig
const clap = b.dependency("clap", .{});
exe.root_module.addImport("clap", clap.module("clap"));
```

### Basic Usage

```zig
const clap = @import("clap");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display this help and exit.
        \\-o, --output <str>     Output file path.
        \\-n, --count <usize>    Number of iterations.
        \\-v, --verbose          Enable verbose output.
        \\<str>...
        \\
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
    }) catch |err| {
        diag.report(err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

    const output = res.args.output orelse "out.txt";
    const count = res.args.count orelse 1;
    const verbose = res.args.verbose != 0;

    for (res.positionals) |file| {
        if (verbose) std.debug.print("Processing: {s}\n", .{file});
        _ = output;
        _ = count;
    }
}
```

### Subcommands

```zig
const main_params = comptime clap.parseParamsComptime(
    \\-h, --help    Display help.
    \\-v, --verbose Enable verbose mode.
    \\<str>
    \\
);

const main_parsers = comptime .{
    .str = clap.parsers.string,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var diag = clap.Diagnostic{};
    var args = std.process.args();

    var res = clap.parseEx(clap.Help, &main_params, main_parsers, &args, .{
        .diagnostic = &diag,
        .allocator = gpa.allocator(),
        .terminating_positional = 0,
    }) catch |err| {
        diag.report(err);
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0)
        return clap.help(std.io.getStdErr().writer(), clap.Help, &main_params, .{});

    const cmd = res.positionals[0] orelse {
        std.debug.print("Expected subcommand: init, build, run\n", .{});
        std.process.exit(1);
    };

    if (std.mem.eql(u8, cmd, "init")) {
        // Handle init subcommand using remaining args
    } else if (std.mem.eql(u8, cmd, "build")) {
        // Handle build subcommand
    } else {
        std.debug.print("Unknown command: {s}\n", .{cmd});
        std.process.exit(1);
    }
}
```

### Custom Type Parsers

```zig
const LogLevel = enum { debug, info, warn, err };

const params = comptime clap.parseParamsComptime(
    \\-l, --log-level <LEVEL>  Set log level (debug, info, warn, err).
    \\
);

const parsers = comptime .{
    .LEVEL = clap.parsers.enumeration(LogLevel),
};

var res = clap.parse(clap.Help, &params, parsers, .{
    .allocator = gpa.allocator(),
}) catch |err| { ... };

const level = res.args.@"log-level" orelse .info;
```

## Environment Variables

```zig
fn getEnvOrDefault(key: []const u8, default: []const u8) []const u8 {
    return std.posix.getenv(key) orelse default;
}

// Usage
const home = getEnvOrDefault("HOME", "/tmp");
const config_path = getEnvOrDefault("MY_CLI_CONFIG", "config.json");
```

## Exit Codes

```zig
const ExitCode = enum(u8) {
    success = 0,
    usage_error = 1,
    runtime_error = 2,
    io_error = 3,
};

fn exit(code: ExitCode) noreturn {
    std.process.exit(@intFromEnum(code));
}
```

## Testing CLI Logic

Separate parsing from execution for testability:

```zig
const Config = struct {
    verbose: bool = false,
    output: []const u8 = "out.txt",
    files: []const []const u8 = &.{},
};

fn execute(config: Config) !void {
    // Business logic here - easy to test
    for (config.files) |file| {
        if (config.verbose) std.debug.print("Processing {s}\n", .{file});
        // ...
    }
}

test "execute with defaults" {
    try execute(.{});
}

test "execute with verbose" {
    try execute(.{ .verbose = true, .files = &.{"test.txt"} });
}
```
