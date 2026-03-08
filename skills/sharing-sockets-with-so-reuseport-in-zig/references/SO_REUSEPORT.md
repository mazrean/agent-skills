# SO_REUSEPORT Technical Reference

## Overview

`SO_REUSEPORT` (Linux 3.9+) allows multiple sockets to bind to the same IP:port. The kernel distributes incoming connections/datagrams across all sockets in the group using a hash-based algorithm. Unlike fork-based socket sharing, each process creates its own independent socket -- no parent-child relationship required.

## How It Differs from SO_REUSEADDR

| Feature | SO_REUSEADDR | SO_REUSEPORT |
|---|---|---|
| Purpose | Skip TIME_WAIT sockets on bind | Allow multiple LISTEN sockets on same port |
| Multiple listeners | No | Yes |
| Load balancing | N/A | Hash-based across all listeners |
| Security | None | EUID check on bind |
| Must set before bind | Recommended | **Required** |

They are independent and can be used together. `SO_REUSEADDR` handles TIME_WAIT bypass; `SO_REUSEPORT` handles multi-listener binding.

## Kernel Internals

### Data Structure

```c
struct sock_reuseport {
    u16 max_socks;        // allocated size
    u16 num_socks;        // current count
    struct sock *socks[]; // flexible array of group members
};
```

Initial allocation: 128 slots, doubles when exceeded.

### Hash Distribution

For TCP, the kernel computes `inet_ehashfn(dst_addr, dst_port, src_addr, src_port)` (full 4-tuple hash), then uses `reciprocal_scale()` to map to a socket index. This means:
- Same client IP:port always maps to the same listener (pseudo-sticky)
- Distribution depends on client address entropy -- clients behind NAT may skew
- **Not sticky across listener count changes** -- adding/removing a listener redistributes mappings

### System Call Sequence

```
socket(AF_INET, SOCK_STREAM, 0)
  -> setsockopt(fd, SOL_SOCKET, SO_REUSEPORT, &1, sizeof(int))  // BEFORE bind
  -> bind(fd, addr, addrlen)
  -> listen(fd, backlog)                                          // joins reuseport group
  -> accept(fd, ...)                                              // receive connections
```

For TCP, the socket does not participate in packet distribution until `listen()` is called.

## Security

### EUID Check

When a socket calls `bind()` with `SO_REUSEPORT`, the kernel checks that the calling process's effective UID matches the EUID of the process that first bound to that address:port. This prevents unprivileged port hijacking.

**Limitation**: Any process running as the same UID can join the group. In shared-UID multi-tenant environments, this is a concern.

### eBPF Socket Selection

For advanced routing (A/B testing, version-based, CPU-affinity):

- `SO_ATTACH_REUSEPORT_CBPF` -- attach classic BPF program
- `SO_ATTACH_REUSEPORT_EBPF` -- attach eBPF program (`BPF_PROG_TYPE_SK_REUSEPORT`)

The eBPF program uses `bpf_sk_select_reuseport()` to pick a socket from a `BPF_MAP_TYPE_REUSEPORT_SOCKARRAY` map. Context provides packet headers, pre-computed hash, and `migrating_sk` for migration scenarios.

## Graceful Restart Race Condition

When a listener leaves/joins, there's a window where in-flight TCP handshakes can fail:

1. SYN arrives, hashed to listener A
2. Listener A closes before ACK completes
3. ACK hashes to listener B (mapping changed), which rejects it with RST

**Impact**: ~2-3 RSTs per million connections per listener change.

### Socket Migration Fix (Linux 5.14+)

Enable: `sysctl net.ipv4.tcp_migrate_req=1`

When a listener closes, its queued connections (both established and mid-handshake) are redistributed to remaining listeners. Off by default for backward compatibility.

eBPF integration: `BPF_SK_REUSEPORT_SELECT_OR_MIGRATE` attach type for custom migration logic.

## Alternative Approaches

### FD Passing via SCM_RIGHTS

One process creates the socket, passes the fd to another via `sendmsg()` on a Unix domain socket with `cmsg_type = SCM_RIGHTS`.

- **Pros**: Zero connection drops (same underlying socket/accept queue)
- **Cons**: Requires coordination channel, sending process must be alive during transfer
- **Best for**: Seamless restarts where zero connection loss is critical (HAProxy model: combines SO_REUSEPORT + SCM_RIGHTS)

### systemd Socket Activation

systemd owns the socket, passes fd to service via `LISTEN_FDS` env var.

- **Pros**: Socket persists across service restarts, listen queue buffers connections
- **Cons**: Single process at a time (no load balancing), requires systemd
- **Best for**: System services with simple restart needs

## Real-World Usage

- **nginx**: `listen 80 reuseport;` -- each worker gets its own socket, eliminates accept lock contention
- **Envoy**: `reuse_port` default on Linux, hot restart via worker-indexed fd transfer
- **HAProxy**: Combines SO_REUSEPORT + SCM_RIGHTS (`expose-fd listeners`) for truly seamless reloads

## Key Gotchas Summary

1. SO_REUSEPORT **must** be set before `bind()` on **all** participating sockets
2. All processes must share the same effective UID
3. Listener count changes cause hash redistribution (RSTs for in-flight handshakes)
4. Socket migration (`tcp_migrate_req`) requires kernel 5.14+ and is off by default
5. Running config-test tools (e.g., `nginx -t`) with reuseport causes brief traffic disruption
6. Hash distribution is not perfectly uniform -- depends on client IP:port entropy
