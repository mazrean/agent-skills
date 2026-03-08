---
name: sharing-sockets-with-so-reuseport-in-zig
description: Writes Zig code for sharing TCP/UDP sockets between unrelated processes using SO_REUSEPORT. Use when implementing multi-process socket sharing, zero-downtime restarts, load balancing across processes, or when user mentions SO_REUSEPORT, reuseport, socket sharing, or graceful restart in a Zig project.
---

# Sharing Sockets with SO_REUSEPORT in Zig

Write Zig code that shares sockets between unrelated processes using `SO_REUSEPORT`. **Use this skill when** building multi-process servers, implementing zero-downtime deployments, or distributing connections across independent Zig processes.

## Quick Start

Minimal SO_REUSEPORT TCP server in Zig -- each process independently binds to the same port:

```zig
const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    const address = try std.net.Address.parseIp("0.0.0.0", 8080);

    const sockfd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM | posix.SOCK.CLOEXEC,
        posix.IPPROTO.TCP,
    );
    defer posix.close(sockfd);

    // SO_REUSEPORT MUST be set BEFORE bind()
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

    try posix.bind(sockfd, &address.any, address.getOsSockLen());
    try posix.listen(sockfd, 128);

    std.debug.print("Listening on :8080 (pid={})\n", .{std.os.linux.getpid()});

    while (true) {
        var client_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);
        const client_fd = try posix.accept(sockfd, &client_addr, &addr_len, posix.SOCK.CLOEXEC);
        defer posix.close(client_fd);

        const response = "HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nOK";
        _ = try posix.write(client_fd, response);
    }
}
```

Compile and run multiple instances: each process independently accepts connections, kernel distributes via hash.

## Critical Rules

1. **`SO_REUSEPORT` before `bind()`** -- mandatory ordering; setting after bind has no effect
2. **ALL sockets must set `SO_REUSEPORT`** -- including the very first one; otherwise subsequent binds fail with `EADDRINUSE`
3. **Same effective UID** -- kernel enforces all processes in a reuseport group share the same EUID
4. **Use raw posix API** -- `std.net.Address.listen()` with `reuse_address = true` sets both `SO_REUSEADDR` and `SO_REUSEPORT`, but for explicit control use `posix.setsockopt()` directly

## Zig Socket API Cheat Sheet

### Option value conversion

`posix.setsockopt()` takes `[]const u8`. Convert typed values:

```zig
// Integer options (c_int)
try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.REUSEPORT,
    &std.mem.toBytes(@as(c_int, 1)));

// Struct options
const timeout = posix.timeval{ .tv_sec = 5, .tv_usec = 0 };  // .sec/.usec in Zig 0.14+
try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.RCVTIMEO,
    std.mem.asBytes(&timeout));
```

### Key constants

| Constant | Path | Value (x86_64) |
|---|---|---|
| `SO.REUSEPORT` | `posix.SO.REUSEPORT` | 15 |
| `SO.REUSEADDR` | `posix.SO.REUSEADDR` | 2 |
| `SOL.SOCKET` | `posix.SOL.SOCKET` | 1 |
| `AF.INET` | `posix.AF.INET` | 2 |
| `SOCK.STREAM` | `posix.SOCK.STREAM` | 1 |
| `SOCK.CLOEXEC` | `posix.SOCK.CLOEXEC` | 0o2000000 |

### Address creation

```zig
// From string
const addr = try std.net.Address.parseIp("0.0.0.0", 8080);

// From raw bytes
const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);

// Pass to bind: &addr.any and addr.getOsSockLen()
```

## Common Patterns

### Zero-Downtime Restart

1. New process starts, sets `SO_REUSEPORT`, binds, listens -- joins existing reuseport group
2. Kernel splits incoming connections across old + new processes (hash-based)
3. Signal old process to stop accepting (close listen fd)
4. Old process drains in-flight requests, then exits

**Gotcha**: During listener count change, in-flight TCP handshakes may get RST'd (~2-3 per million connections). On Linux 5.14+, enable socket migration: `sysctl net.ipv4.tcp_migrate_req=1`.

### High-Level API Alternative

```zig
const address = try std.net.Address.parseIp("0.0.0.0", 8080);
var server = try address.listen(.{
    .reuse_address = true,  // sets BOTH SO_REUSEADDR and SO_REUSEPORT
    .kernel_backlog = 128,
});
defer server.deinit();
const conn = try server.accept();  // returns Server.Connection
```

Note: `reuse_address = true` enables SO_REUSEPORT on Linux. This is a known naming inconsistency (see [zig#24838](https://github.com/ziglang/zig/issues/24838)).

## Detailed References

- **SO_REUSEPORT internals, security, eBPF steering**: See [SO_REUSEPORT.md](references/SO_REUSEPORT.md)
- **Zig socket API details, raw syscalls, error handling**: See [ZIG-SOCKET-API.md](references/ZIG-SOCKET-API.md)
- **Full code examples (multi-process server, graceful restart, UDP)**: See [EXAMPLES.md](references/EXAMPLES.md)
