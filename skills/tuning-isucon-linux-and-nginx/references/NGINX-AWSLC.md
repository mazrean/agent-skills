# Prebuilt nginx + AWS-LC (no build on contest day)

Ubuntu's nginx links OpenSSL 3.0, whose provider layer costs a lot per small
TLS record. Swapping the TLS library to AWS-LC plus three syscall-saving
patches gave **+5 % score** and **+10 pt idle CPU** on every TLS-terminating
host in the observed run — with no config change.

A second run measured the same swap on c5.large-class hosts: **1,440 vs 1,132
full handshakes/s (+27 %)** at saturation.

## Install (5 minutes, every TLS host)

```sh
TAG=nginx-awslc-1.28.0-awslc1.62.0-r1
BASE=https://github.com/mazrean/agent-skills/releases/download/$TAG
curl -fsSLO "$BASE/nginx-awslc"
# pinned here (not only in the release) so a swapped asset cannot swap its own checksum
echo "43e6fb7f12e38110d1113b01d768f8dae780d9cd3513e600dbd96b94292462a5  nginx-awslc" | sha256sum -c
sudo install -m 755 nginx-awslc /usr/local/sbin/nginx-awslc
/usr/local/sbin/nginx-awslc -V 2>&1 | head -3        # nginx/1.28.0, AWS-LC 1.62.0

# keep the Ubuntu package (paths, unit, logrotate); override only the binary
sudo mkdir -p /etc/systemd/system/nginx.service.d
sudo install -m 644 assets/nginx-awslc/nginx-awslc.conf /etc/systemd/system/nginx.service.d/awslc.conf
sudo /usr/local/sbin/nginx-awslc -t && sudo systemctl daemon-reload && sudo systemctl restart nginx
```

Put the binary and the drop-in in the repo and let the deploy script install
them, so a fresh host or a reboot ends up identical.

Binary properties: x86-64-v2, dynamically linked against libc only, highest
symbol version `GLIBC_2.34`; AWS-LC, PCRE2 (JIT) and zlib are static.
**Verified** on Ubuntu 24.04 (TLS 1.3 + X25519 + ECDSA, h2, HTTP/1.1,
`reuseport`, `worker_cpu_affinity`, `gzip_static`, keepalive upstream).
Ubuntu 22.04 / Debian 12 are **expected** to work from the symbol versions but
were not run.
Same paths as the Ubuntu package (`/etc/nginx`, `/var/log/nginx`,
`/var/lib/nginx/*`), so existing configs work unchanged.

Modules: http, ssl, v2, gzip_static, stub_status, realip, threads, proxy,
fastcgi/uwsgi/scgi, rewrite (PCRE2). **Not included**: `auth_basic`,
`stream`, HTTP/3, dynamic modules. If the contest config needs one of those,
rebuild (below) or keep the stock nginx for that host.

Revert: `sudo rm /etc/systemd/system/nginx.service.d/awslc.conf && sudo systemctl daemon-reload && sudo systemctl restart nginx`.

## What is patched (and why)

| Patch | Effect observed |
|---|---|
| `awslc-sock-no-soerror` — AWS-LC's socket BIO no longer calls `getsockopt(SO_ERROR)` on every read/write (BoringSSL/OpenSSL do not on POSIX) | ~40 % of a worker's syscalls disappeared (52k → 247 per 3 s window) |
| `nginx-upstream-cached-no-soerror` — skip the connect-check `getsockopt` on keepalive-reused upstream connections | removes one syscall per proxied request |
| `awslc-sock-short-read-flag` + `nginx-ssl-recv-short-read` — when the socket read was short and no TLS data is pending, stop instead of issuing a read that returns `EAGAIN` (epoll + `EPOLLRDHUP` only, same condition as plain `ngx_unix_recv`) | `EAGAIN` reads fell from ~50 % to ~7 % of reads |
| `nginx-incoming-cpu` — a `reuseport` listener in a worker pinned to one CPU sets `SO_INCOMING_CPU` to that CPU | Linux 6.x `reuseport_select_sock_by_hash()` then hands each connection to the worker on the CPU that took its SYN (pairs with NET-TUNE IRQ pinning) |

Validated in the original run (gcc build of the same sources; the syscall
numbers above come from that run's strace, not re-measured on this build):
3 MB POST round-trip, 200 parallel h2 GETs of mixed
sizes, HTTP/1.1, SSE streaming, a full benchmark pass with no new errors, and
no leftover connections after the run.

**Further AWS-LC patches (gray zone, not in this build).** The second run's
best score used AWS-LC with RSA blinding removed, the post-sign verification
removed, and the AVX2 `rsaz` path preferred when both hyperthreads are busy
(they share the scalar multiplier): 1,818 → 2,162 RSA-2048 signs/s, +11 %
saturated handshakes, checked with 1.1M signatures and Chromium/curl/Go
clients. Removing blinding weakens timing side-channel resistance — use only
if the regulation and the team's policy allow it, and never outside the
contest.

To get the CPU alignment, use it together with:

```nginx
worker_processes auto;
worker_cpu_affinity auto;
...
listen 443 ssl reuseport;
```

## Rebuild (only if a module is missing or the host is not x86-64)

```sh
# portable (needs zig: glibc 2.35 target, x86-64-v2), ~5 min on 8 cores
OUT=dist/nginx-awslc assets/nginx-awslc/build.sh
# on the target host itself with gcc, tuned to its CPU
PORTABLE=0 MARCH=native OUT=/tmp/nginx-awslc assets/nginx-awslc/build.sh
```

Add `--with-...` flags in `build.sh` as needed. Building the `stream` module
against AWS-LC fails (`SSL_SESSION_get0_hostname` is missing), so it is off.
Build on a machine that is not serving the benchmark.
