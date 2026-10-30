# nginx Configuration Skeleton

Problem-independent parts of the final config. Replace upstream addresses,
`server_name`, `root`, and the long-lived endpoint paths.

## Main context

```nginx
user www-data;
worker_processes auto;
worker_cpu_affinity auto;        # worker N on CPU N; aligns with NIC queue N (NET-TUNE)
worker_rlimit_nofile 100000;
pid /run/nginx.pid;
error_log /var/log/nginx/error.log;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 16384;
    multi_accept on;
    use epoll;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    server_tokens off;
    keepalive_timeout 65;
    keepalive_requests 100000;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    access_log off;                # turn on (LTSV) only while profiling with alp
    gzip off;                      # serve pre-compressed files with gzip_static instead

    open_file_cache max=10000 inactive=60s;
    open_file_cache_valid 120s;
    open_file_cache_min_uses 1;
    open_file_cache_errors on;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    ssl_session_tickets on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
```

## Upstream: keep connections alive

```nginx
upstream app {
    server 127.0.0.1:8080;                 # or: server unix:/run/app/app.sock;
    keepalive 256;
    keepalive_requests 100000;
    keepalive_timeout 120s;
}
```

Every `location` that proxies must inherit (set at `server` level, never
re-declare `proxy_set_header` inside a location or these are lost):

```nginx
proxy_http_version 1.1;
proxy_set_header Connection "";
proxy_set_header Host $host;
```

Check: `accept/s` on the app host in `node-metrics.sh` should be near zero
under load. 30k passive opens / 41 s was observed when this was broken.

### Unix socket for co-located nginx → app

Only when nginx and the app share a host. Run nginx with **1 worker** on that
host (it competes with the app for CPU). Across hosts stay on TCP.

```nginx
upstream app_local { server unix:/run/app/app.sock; keepalive 256; }
```

App side: listen on the socket, `chmod 666` it (nginx runs as `www-data`), and
create `/run/app` via `RuntimeDirectory=app` in the systemd unit so it survives
reboot.

## TLS

```nginx
server {
    listen 443 ssl reuseport;          # reuseport + nginx-awslc → SO_INCOMING_CPU per worker
    http2 on;                          # nginx ≥ 1.25.1 syntax; older: listen ... http2
    http2_max_concurrent_streams 1024;
    server_name example.isucon.net;

    ssl_protocols TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_ecdh_curve X25519;
    ssl_certificate     /etc/nginx/tls/server.crt;
    ssl_certificate_key /etc/nginx/tls/server.key;
    ...
}
```

- `reuseport` may appear on only one `listen` per address:port across all
  server blocks.
- **Certificate**: an ECDSA P-256 key makes each handshake much cheaper than
  RSA-2048 (+3 % score observed). Only replace the provided certificate if the
  regulation allows it and the benchmarker does not verify it. If the provided
  certificate is RSA and must stay, the other levers here still apply.
- HTTP/1.1 to the client was 5 % slower than h2 in the observed workload.

## Static files

```nginx
root /home/isucon/webapp/public/;

location /assets/ {
    gzip_static on;                    # pre-compress: gzip -k -9 assets/*  (deploy step)
    expires max;
    add_header Cache-Control "public, immutable";
    try_files $uri =404;
}
location / {
    try_files $uri /index.html;        # SPA fallback
}
```

Caching headers change **client** behaviour, and the benchmarker is the client:
in one phase `max-age` on everything cost 35 % (the client's per-user cache
grew and its memory/CPU became the limit); later, with a larger bench host,
caching index.html for 1 day gained 3 %. Always A/B cache headers; never
assume.

Large responses on the front host count against cloud NIC allowances — keep
`gzip_static` on for anything big (see NET-TUNE).

## Long-lived endpoints (SSE / long-poll)

```nginx
location /api/notification {
    proxy_pass http://app;
    proxy_buffering off;
    proxy_cache off;
    proxy_read_timeout 3600s;
}
```

## Internal-only endpoints

```nginx
location /api/internal/ { allow 127.0.0.1; deny all; proxy_pass http://app; }
```

## Swapping the nginx binary without touching packages

Keep the Ubuntu package (unit, paths, logrotate) and override only the binary
with a systemd drop-in — see [NGINX-AWSLC.md](NGINX-AWSLC.md).
