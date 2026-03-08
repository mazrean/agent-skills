# Code Examples

## 1. Multi-Process TCP Server with SO_REUSEPORT

Run multiple instances of this binary. Each process independently binds to port 8080 and accepts connections. The kernel distributes connections via hash.

```zig
const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    const pid = std.os.linux.getpid();
    const address = try std.net.Address.parseIp("0.0.0.0", 8080);

    const sockfd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM | posix.SOCK.CLOEXEC,
        posix.IPPROTO.TCP,
    );
    defer posix.close(sockfd);

    // Both options set BEFORE bind
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

    try posix.bind(sockfd, &address.any, address.getOsSockLen());
    try posix.listen(sockfd, 128);

    std.debug.print("[pid={d}] Listening on :8080\n", .{pid});

    while (true) {
        var client_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);
        const client_fd = posix.accept(sockfd, &client_addr, &addr_len, posix.SOCK.CLOEXEC) catch |err| {
            std.debug.print("[pid={d}] accept error: {}\n", .{ pid, err });
            continue;
        };
        defer posix.close(client_fd);

        std.debug.print("[pid={d}] Accepted connection\n", .{pid});

        var buf: [4096]u8 = undefined;
        _ = posix.read(client_fd, &buf) catch continue;

        const body = std.fmt.comptimePrint("Handled by process\n", .{});
        const response = "HTTP/1.1 200 OK\r\n" ++
            "Content-Length: " ++ std.fmt.comptimePrint("{d}", .{body.len}) ++ "\r\n" ++
            "Connection: close\r\n\r\n" ++ body;
        _ = posix.write(client_fd, response) catch {};
    }
}
```

### Running

```bash
# Terminal 1
zig build-exe server.zig && ./server

# Terminal 2
./server

# Terminal 3 -- test
for i in $(seq 1 10); do curl -s http://localhost:8080/; done
# Connections are distributed across both processes
```

## 2. Graceful Restart Pattern

Old process receives SIGTERM, stops accepting, drains connections, then exits. New process starts independently and joins the reuseport group.

```zig
const std = @import("std");
const posix = std.posix;

var running: bool = true;

fn sigterm_handler(_: c_int) callconv(.c) void {
    running = false;
}

pub fn main() !void {
    const pid = std.os.linux.getpid();

    // Install SIGTERM handler
    const sa = posix.Sigaction{
        .handler = .{ .handler = sigterm_handler },
        .mask = posix.empty_sigset,
        .flags = 0,
    };
    try posix.sigaction(posix.SIG.TERM, &sa, null);

    const address = try std.net.Address.parseIp("0.0.0.0", 8080);

    const sockfd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.STREAM | posix.SOCK.CLOEXEC | posix.SOCK.NONBLOCK,
        posix.IPPROTO.TCP,
    );
    defer posix.close(sockfd);

    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));
    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

    try posix.bind(sockfd, &address.any, address.getOsSockLen());
    try posix.listen(sockfd, 128);

    std.debug.print("[pid={d}] Listening on :8080\n", .{pid});

    while (running) {
        var client_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);
        const client_fd = posix.accept(sockfd, &client_addr, &addr_len, posix.SOCK.CLOEXEC) catch |err| {
            if (err == error.WouldBlock) {
                std.time.sleep(10 * std.time.ns_per_ms);
                continue;
            }
            std.debug.print("[pid={d}] accept error: {}\n", .{ pid, err });
            continue;
        };
        defer posix.close(client_fd);

        // Handle request...
        var buf: [4096]u8 = undefined;
        _ = posix.read(client_fd, &buf) catch continue;
        _ = posix.write(client_fd, "HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK") catch {};
    }

    std.debug.print("[pid={d}] Shutting down gracefully\n", .{pid});
    // Drain phase: close listen socket (already deferred), finish in-flight work
}
```

### Restart flow

```bash
# Start old process
./server &
OLD_PID=$!

# Start new process (joins reuseport group immediately)
./server &

# Stop old process (drains and exits)
kill -TERM $OLD_PID
# Zero-downtime: new process continues serving
```

## 3. UDP with SO_REUSEPORT

```zig
const std = @import("std");
const posix = std.posix;

pub fn main() !void {
    const pid = std.os.linux.getpid();
    const address = try std.net.Address.parseIp("0.0.0.0", 9090);

    const sockfd = try posix.socket(
        posix.AF.INET,
        posix.SOCK.DGRAM | posix.SOCK.CLOEXEC,
        posix.IPPROTO.UDP,
    );
    defer posix.close(sockfd);

    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEPORT, &std.mem.toBytes(@as(c_int, 1)));

    try posix.bind(sockfd, &address.any, address.getOsSockLen());

    std.debug.print("[pid={d}] Listening UDP on :9090\n", .{pid});

    var buf: [65536]u8 = undefined;
    while (true) {
        var src_addr: posix.sockaddr = undefined;
        var addr_len: posix.socklen_t = @sizeOf(posix.sockaddr);

        const len = posix.recvfrom(sockfd, &buf, 0, &src_addr, &addr_len) catch |err| {
            std.debug.print("[pid={d}] recvfrom error: {}\n", .{ pid, err });
            continue;
        };

        std.debug.print("[pid={d}] Received {d} bytes\n", .{ pid, len });

        // Echo back
        _ = posix.sendto(sockfd, buf[0..len], 0, &src_addr, addr_len) catch {};
    }
}
```

## 4. High-Level API (Simple Case)

When explicit `SO_REUSEPORT` control isn't needed:

```zig
const std = @import("std");

pub fn main() !void {
    const address = try std.net.Address.parseIp("0.0.0.0", 8080);

    // reuse_address = true sets BOTH SO_REUSEADDR and SO_REUSEPORT on Linux
    var server = try address.listen(.{
        .reuse_address = true,
        .kernel_backlog = 128,
    });
    defer server.deinit();

    std.debug.print("Listening on :8080\n", .{});

    while (true) {
        const conn = try server.accept();
        defer conn.stream.close();

        var buf: [4096]u8 = undefined;
        _ = conn.stream.read(&buf) catch continue;
        _ = conn.stream.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nOK") catch {};
    }
}
```

## 5. Verifying SO_REUSEPORT Is Working

Check from the shell:

```bash
# Show all sockets bound to port 8080
ss -tlnp sport = :8080

# Expected output: multiple LISTEN entries with different PIDs
# LISTEN  0  128  0.0.0.0:8080  0.0.0.0:*  users:(("server",pid=1234,fd=3))
# LISTEN  0  128  0.0.0.0:8080  0.0.0.0:*  users:(("server",pid=1235,fd=3))
```
