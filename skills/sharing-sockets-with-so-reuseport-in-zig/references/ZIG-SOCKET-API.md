# Zig Socket API Reference

## Module Structure

| Module | Purpose |
|---|---|
| `std.posix` | Cross-platform POSIX wrappers with error unions |
| `std.os.linux` | Raw Linux syscall wrappers returning `usize` |
| `std.net` | High-level networking (Address, Server, Stream) |

## std.posix -- Socket Functions

### socket
```zig
pub fn socket(domain: u32, socket_type: u32, protocol: u32) SocketError!socket_t
```
Errors: `PermissionDenied`, `AddressFamilyNotSupported`, `ProtocolFamilyNotAvailable`, `ProcessFdQuotaExceeded`, `SystemFdQuotaExceeded`, `SystemResources`, `ProtocolNotSupported`, `SocketTypeNotSupported`, `UnexpectedError`

### setsockopt
```zig
pub fn setsockopt(fd: socket_t, level: i32, optname: u32, opt: []const u8) SetSockOptError!void
```
The `opt` parameter is a byte slice. Use `std.mem.toBytes()` or `std.mem.asBytes()` to convert typed values.

Errors: `AlreadyConnected`, `InvalidProtocolOption`, `TimeoutTooBig`, `SystemResources`, `PermissionDenied`, `NetworkSubsystemFailed`, `FileDescriptorNotASocket`, `SocketNotBound`, `NoDevice`, `UnexpectedError`

### bind
```zig
pub fn bind(sock: socket_t, addr: *const sockaddr, len: socklen_t) BindError!void
```
Errors: `AccessDenied`, `AddressInUse`, `AddressNotAvailable`, `AddressFamilyNotSupported`, `SymLinkLoop`, `NameTooLong`, `FileNotFound`, `SystemResources`, `NotDir`, `ReadOnlyFileSystem`, `NetworkSubsystemFailed`, `FileDescriptorNotASocket`, `AlreadyBound`, `UnexpectedError`

### listen
```zig
pub fn listen(sock: socket_t, backlog: u31) ListenError!void
```
Errors: `AddressInUse`, `FileDescriptorNotASocket`, `OperationNotSupported`, `NetworkSubsystemFailed`, `SystemResources`, `AlreadyConnected`, `SocketNotBound`, `UnexpectedError`

### accept
```zig
pub fn accept(sock: socket_t, addr: ?*sockaddr, addr_size: ?*socklen_t, flags: u32) AcceptError!socket_t
```
Errors: `ConnectionAborted`, `FileDescriptorNotASocket`, `ProcessFdQuotaExceeded`, `SystemFdQuotaExceeded`, `SystemResources`, `SocketNotListening`, `ProtocolFailure`, `BlockedByFirewall`, `WouldBlock`, `ConnectionResetByPeer`, `NetworkSubsystemFailed`, `OperationNotSupported`, `UnexpectedError`

## Constants

### Socket Options (posix.SO)
```zig
posix.SO.REUSEPORT  // 15 on x86_64
posix.SO.REUSEADDR  // 2
posix.SO.KEEPALIVE  // 9
posix.SO.RCVTIMEO   // 20
posix.SO.SNDTIMEO   // 21
posix.SO.SNDBUF     // 7
posix.SO.RCVBUF     // 8
posix.SO.LINGER     // 13
```
Note: Values are architecture-dependent (MIPS, SPARC, PPC differ).

### Socket Level
```zig
posix.SOL.SOCKET  // 1 on x86_64 (65535 on MIPS/SPARC)
```

### Address Families
```zig
posix.AF.INET    // IPv4
posix.AF.INET6   // IPv6
posix.AF.UNIX    // Unix domain
```

### Socket Types
```zig
posix.SOCK.STREAM    // TCP (1)
posix.SOCK.DGRAM     // UDP (2)
posix.SOCK.NONBLOCK  // 0o4000
posix.SOCK.CLOEXEC   // 0o2000000
```

### Protocols
```zig
posix.IPPROTO.TCP  // 6
posix.IPPROTO.UDP  // 17
```

## std.net -- High-Level API

### Address

```zig
pub const Address = extern union {
    any: posix.sockaddr,
    in: Ip4Address,
    in6: Ip6Address,
    un: posix.sockaddr.un,
};
```

Creation:
```zig
const addr = try std.net.Address.parseIp("0.0.0.0", 8080);      // from string
const addr = std.net.Address.initIp4(.{ 127, 0, 0, 1 }, 8080);  // from bytes
```

Passing to posix functions:
```zig
try posix.bind(sockfd, &addr.any, addr.getOsSockLen());
```

### Server

```zig
var server = try address.listen(.{
    .reuse_address = true,    // sets SO_REUSEADDR + SO_REUSEPORT
    .kernel_backlog = 128,
});
defer server.deinit();

const conn = try server.accept();
// conn.stream: std.net.Stream (has .read(), .write(), .close())
// conn.address: std.net.Address (peer address)
```

**Known issue**: `reuse_address = true` sets both `SO_REUSEADDR` and `SO_REUSEPORT` on Linux. There is no way to set only one. For explicit control, use the raw posix API.

## Type Conversion for setsockopt

### Integer options
```zig
// std.mem.toBytes converts value to [N]u8, & coerces to slice
try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.REUSEPORT,
    &std.mem.toBytes(@as(c_int, 1)));
```

### Struct options
```zig
// std.mem.asBytes converts pointer-to-struct to byte slice
const linger_val = posix.linger{ .l_onoff = 1, .l_linger = 5 };
try posix.setsockopt(fd, posix.SOL.SOCKET, posix.SO.LINGER,
    std.mem.asBytes(&linger_val));
```

## Raw Linux Syscalls

When no `std.posix` wrapper exists, use raw syscalls:

```zig
const linux = std.os.linux;

// Direct syscall -- returns usize, check errno manually
const rc = linux.syscall3(
    .some_syscall,
    @intCast(arg1),
    @intCast(arg2),
    @intCast(arg3),
);
const err = std.posix.errno(rc);
if (err != .SUCCESS) {
    // handle error
}
```

### Syscall functions (architecture-specific)
```zig
pub fn syscall0(number: SYS) usize
pub fn syscall1(number: SYS, arg1: usize) usize
pub fn syscall2(number: SYS, arg1: usize, arg2: usize) usize
// ... up to syscall6
```

`SYS` is an enum that switches on CPU architecture, mapping to arch-specific syscall numbers.

## Zig Version Differences

| Feature | Zig 0.13 | Zig 0.14+ |
|---|---|---|
| `posix.timeval` fields | `.tv_sec`, `.tv_usec` | `.sec`, `.usec` |
| Socket API location | `std.posix` | `std.posix` (same) |
| High-level server | `std.net.Address.listen()` | Same (0.16 may introduce `std.Io.net`) |
