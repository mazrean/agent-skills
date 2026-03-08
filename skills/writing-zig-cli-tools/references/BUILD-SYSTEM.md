# Zig Build System Reference

## Project Initialization

```bash
mkdir my-cli && cd my-cli
mkdir src
# Create build.zig, build.zig.zon, and src/main.zig
```

## build.zig.zon Template

```zig
.{
    .name = .{ "my-cli" },
    .version = "0.1.0",
    .fingerprint = .auto,
    .minimum_zig_version = "0.15.0",
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
    .dependencies = .{},
}
```

## Full build.zig Template

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Main executable
    const exe = b.addExecutable(.{
        .name = "my-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    // Run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);

    // Test step
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

## Adding Dependencies

### Fetch and save a dependency
```bash
zig fetch --save git+https://github.com/Hejsil/zig-clap
```

This adds an entry to `build.zig.zon`:
```zig
.dependencies = .{
    .clap = .{
        .url = "git+https://github.com/Hejsil/zig-clap",
        .hash = "...",
    },
},
```

### Use dependency in build.zig
```zig
const clap = b.dependency("clap", .{});
exe.root_module.addImport("clap", clap.module("clap"));
```

## Compile-Time Options

Pass configuration values at build time:

```zig
// In build.zig
const options = b.addOptions();
options.addOption([]const u8, "version", "1.0.0");
options.addOption(bool, "enable_debug", optimize == .Debug);
exe.root_module.addOptions("config", options);
```

```zig
// In src/main.zig
const config = @import("config");
const version = config.version;
```

## Linking System Libraries

```zig
exe.root_module.linkSystemLibrary("z", .{});
exe.root_module.linkLibC();
```

## Multi-Target Release Builds

```zig
const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux },
    .{ .cpu_arch = .aarch64, .os_tag = .linux },
    .{ .cpu_arch = .x86_64, .os_tag = .macos },
    .{ .cpu_arch = .aarch64, .os_tag = .macos },
    .{ .cpu_arch = .x86_64, .os_tag = .windows },
};

for (targets) |t| {
    const resolved = b.resolveTargetQuery(t);
    const cross_exe = b.addExecutable(.{
        .name = "my-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = resolved,
            .optimize = .ReleaseSafe,
        }),
    });

    const target_output = b.addInstallArtifact(cross_exe, .{
        .dest_dir = .{
            .override = .{
                .custom = resolved.result.zigTriple(),
            },
        },
    });
    b.getInstallStep().dependOn(&target_output.step);
}
```

## Common Build Commands

```bash
# Build
zig build

# Build and run
zig build run

# Run with arguments
zig build run -- --flag value

# Run tests
zig build test

# Build with optimization
zig build -Doptimize=ReleaseSafe

# Cross-compile
zig build -Dtarget=aarch64-linux

# Watch mode (fast rebuild)
zig build --watch -fincremental
```
