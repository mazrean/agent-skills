# Zig 0.15+ Syntax & Migration Guide

## I/O: Buffered Writer/Reader

### Old Pattern (pre-0.15)
```zig
const stdout = std.io.getStdOut().writer();
try stdout.print("Hello\n", .{});
```

### New Pattern (0.15+)
```zig
var stdout_buf: [4096]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
const stdout = &stdout_writer.interface;

try stdout.print("Hello\n", .{});
try stdout.flush(); // REQUIRED
```

### Unbuffered (empty buffer)
```zig
var writer = std.fs.File.stderr().writer(&.{});
const stderr = &writer.interface;
try stderr.print("immediate\n", .{});
```

### Generic Writer Functions
```zig
fn writeOutput(writer: *std.Io.Writer, msg: []const u8) !void {
    try writer.print("{s}\n", .{msg});
}
```

### Reading from Stdin
```zig
var stdin_buf: [4096]u8 = undefined;
var stdin_wrapper = std.fs.File.stdin().reader(&stdin_buf);
const reader = &stdin_wrapper.interface;

while (reader.takeDelimiterExclusive('\n')) |line| {
    // process line
} else |err| switch (err) {
    error.EndOfStream => {},
    error.StreamTooLong => return err,
    error.ReadFailed => return err,
}
```

## ArrayList: Unmanaged by Default

### Old Pattern
```zig
var list = std.ArrayList(i32).init(allocator);
defer list.deinit();
try list.append(42);
```

### New Pattern (0.15+)
```zig
var list: std.ArrayListUnmanaged(i32) = .{};
defer list.deinit(allocator);
try list.append(allocator, 42);
try list.ensureTotalCapacity(allocator, 100);
```

All mutating operations require the allocator parameter.

## Type Reflection Tags: Lowercase

### Old Pattern
```zig
switch (@typeInfo(T)) {
    .Int => {},
    .Struct => {},
    .Enum => {},
}
```

### New Pattern (0.15+)
```zig
switch (@typeInfo(T)) {
    .int => {},
    .@"struct" => {},  // Keywords use @"" syntax
    .@"enum" => {},
    .pointer => {},
    .optional => {},
}
```

## Build System Changes

### Old Pattern
```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_source_file = .{ .path = "src/main.zig" },
    .target = target,
    .optimize = optimize,
});
```

### New Pattern (0.15+)
```zig
const exe = b.addExecutable(.{
    .name = "app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

### Libraries
```zig
// Old: b.addStaticLibrary() - REMOVED
// New:
const lib = b.addLibrary(.{
    .name = "mylib",
    .linkage = .static,
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }),
});
```

## Branch Hints (replaces @setCold)

### Old Pattern
```zig
@setCold(true);
```

### New Pattern (0.15+)
```zig
@branchHint(.cold);
@branchHint(.likely);
@branchHint(.unlikely);
```

## @export Requires Pointer

### Old Pattern
```zig
@export(myFunction, .{ .name = "my_func" });
```

### New Pattern (0.15+)
```zig
@export(&myFunction, .{ .name = "my_func" });
```

## Labeled Switch with Continue

```zig
state_loop: switch (state) {
    .start => {
        state = .reading;
        continue :state_loop;
    },
    .reading => {
        // process
        state = .done;
        continue :state_loop;
    },
    .done => {},
}
```

## Signal Handling (POSIX)

Use lowercase `.c` calling convention:

```zig
fn sigintHandler(_: c_int) callconv(.c) void {
    g_cancel_flag.store(true, .release);
}

const act = std.posix.Sigaction{
    .handler = .{ .handler = sigintHandler },
    .mask = std.mem.zeroes(std.posix.sigset_t),
    .flags = 0,
};
std.posix.sigaction(std.posix.SIG.INT, &act, null);
```

## Standard Library Renames

| Old Name | New Name (0.15+) |
|----------|-------------------|
| `std.rand` | `std.Random` |
| `std.TailQueue` | `std.DoublyLinkedList` |
| `std.zig.CrossTarget` | `std.Target.Query` |
| `std.fs.MAX_PATH_BYTES` | `std.fs.max_path_bytes` |

## Page Size

```zig
// Runtime (preferred)
const page_size = std.heap.pageSize();

// Compile-time bounds
const min_page = std.heap.page_size_min;
const max_page = std.heap.page_size_max;
```

## Common Pitfalls

1. **Forgetting `stdout.flush()`** - Output won't appear
2. **Using `ArrayList.init(allocator)`** - Use `.{}` literal instead
3. **Omitting allocator in ArrayList ops** - All mutations need it
4. **Using uppercase type tags** - `.Int` is now `.int`
5. **Using `.C` calling convention** - It's `.c` (lowercase)
6. **Using `addStaticLibrary()`** - Use `addLibrary(.{ .linkage = .static, ... })`
7. **Using `root_source_file` directly in addExecutable** - Use `root_module` with `b.createModule()`
