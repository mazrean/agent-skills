---
name: writing-zig-cli-tools
description: Writes CLI tools in Zig using modern 0.15+ syntax and best practices. Use when creating command-line applications in Zig, parsing CLI arguments, setting up Zig project structure with build.zig, or working with Zig's I/O and error handling for CLI programs.
---

# Writing Zig CLI Tools

Build high-performance CLI tools in Zig using modern 0.15+ idioms. Covers project setup, argument parsing, I/O, error handling, and cross-compilation.

**Use this skill when** creating CLI applications in Zig, parsing command-line arguments, setting up `build.zig` projects, or writing robust terminal I/O code.

**Supporting files:** [SYNTAX-GUIDE.md](references/SYNTAX-GUIDE.md) for 0.15+ syntax changes, [BUILD-SYSTEM.md](references/BUILD-SYSTEM.md) for build.zig patterns, [ARGUMENT-PARSING.md](references/ARGUMENT-PARSING.md) for CLI argument handling.

## Quick Start

### Project Structure

```
my-cli/
├── build.zig
├── build.zig.zon
└── src/
    └── main.zig
```

### Minimal build.zig

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "my-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
```

### Minimal build.zig.zon

```zig
.{
    .name = .{ "my-cli" },
    .version = "0.1.0",
    .fingerprint = .auto,
    .minimum_zig_version = "0.15.0",
    .paths = .{ "build.zig", "build.zig.zon", "src" },
    .dependencies = .{},
}
```

### Minimal main.zig (0.15+ I/O)

```zig
const std = @import("std");

pub fn main() !void {
    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    var stderr_buf: [4096]u8 = undefined;
    var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
    const stderr = &stderr_writer.interface;

    // Parse arguments
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.next(); // skip program name

    const filename = args.next() orelse {
        try stderr.print("Usage: my-cli <filename>\n", .{});
        try stderr.flush();
        std.process.exit(1);
    };

    try stdout.print("Processing: {s}\n", .{filename});
    try stdout.flush();
}
```

## Critical: 0.15+ I/O Pattern

Zig 0.15+ uses **buffered I/O by default**. Always flush before exit:

```zig
var buf: [4096]u8 = undefined;
var writer = std.fs.File.stdout().writer(&buf);
const stdout = &writer.interface;

try stdout.print("output\n", .{});
try stdout.flush(); // REQUIRED - output won't appear without this
```

For unbuffered I/O (debugging, progress output):

```zig
var writer = std.fs.File.stderr().writer(&.{});
const stderr = &writer.interface;
try stderr.print("debug: immediate output\n", .{});
// No flush needed with empty buffer
```

## Argument Parsing with zig-clap

For complex CLI tools, use [zig-clap](https://github.com/Hejsil/zig-clap):

```bash
zig fetch --save git+https://github.com/Hejsil/zig-clap
```

Add to `build.zig`:

```zig
const clap = b.dependency("clap", .{});
exe.root_module.addImport("clap", clap.module("clap"));
```

Usage:

```zig
const clap = @import("clap");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help             Display help and exit.
        \\-o, --output <str>     Output file path.
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

    if (res.args.help != 0) {
        return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
    }

    for (res.positionals) |pos| {
        std.debug.print("positional: {s}\n", .{pos});
    }
}
```

## Error Handling Patterns

```zig
pub fn main() !void {
    run() catch |err| {
        var stderr_buf: [4096]u8 = undefined;
        var stderr_writer = std.fs.File.stderr().writer(&stderr_buf);
        const stderr = &stderr_writer.interface;
        try stderr.print("Error: {}\n", .{err});
        try stderr.flush();
        std.process.exit(1);
    };
}

fn run() !void {
    // Application logic here
    // Errors propagate naturally with `try`
}
```

## File I/O

```zig
fn readFile(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(usize));
}

fn writeFile(path: []const u8, data: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try file.writeAll(data);
}
```

## Cross-Compilation

Build for multiple targets:

```bash
zig build -Dtarget=x86_64-linux
zig build -Dtarget=aarch64-macos
zig build -Dtarget=x86_64-windows
```

## Key 0.15+ Gotchas

1. **Always flush stdout/stderr** before program exit
2. **ArrayList is unmanaged** - pass allocator to each method: `try list.append(allocator, val)`
3. **Type tags are lowercase** - `.int`, `.@"struct"`, `.pointer`
4. **Use `b.createModule()`** in build.zig, not `root_source_file` directly
5. **Use `b.addLibrary()`** instead of removed `addStaticLibrary()`
6. **Calling convention is `.c`** (lowercase), not `.C`

See [SYNTAX-GUIDE.md](references/SYNTAX-GUIDE.md) for complete 0.15+ migration details.
