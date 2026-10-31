---
name: tuning-isucon-linux-and-nginx
description: Problem-independent infrastructure tuning for ISUCON-style multi-host web apps on Linux, distilled from a 17-hour measured tuning run (1,085 → ~2.9M). Covers a prebuilt nginx 1.28 + AWS-LC binary with syscall-saving patches (drop-in replacement, no build needed), TLS termination spread across hosts with netfilter DNAT + nftables flowtable, NIC IRQ / XPS / SO_INCOMING_CPU alignment, sysctl, cloud NIC allowance limits (EC2 ENA bw/pps), per-host cost measurement that does not need a benchmark run, transferable app patterns (in-memory + local WAL, long-poll, SSE, Go→Rust), and a prebuilt patched kernel + XDP load balancer that cuts front-host packet CPU (with when it pays), and a list of measured dead ends (XDP on stock ENA, NAPI deferral, NOTRACK). Use when tuning nginx/TLS/kernel/NIC on ISUCON hosts, when the app is no longer the only bottleneck, or when deciding which infra levers are worth contest time.
version: 1.3.0
---

# Tuning ISUCON Linux and nginx

Infra levers that carried over across the whole run, ordered by **cost × yield**.
Everything here is independent of the problem's domain; only the host names and
the app's upstream change. For contest strategy see `winning-isucon`; for how an
agent should run the contest (bench queue, parallel agents, stalls) see
`running-isucon-as-an-agent`.

**Use this skill when** the app is already reasonable (no N+1, data in memory or
indexed) and per-host CPU shows nginx/TLS/softirq near the top, or when deciding
which infra work is worth contest time.

## Ground rules (learned the hard way)

1. **Measure the hosts, not just the score.** Scores varied ±5–12 % run to run;
   per-host CPU split (usr/sys/soft/idle), egress, and allowance counters are far
   more stable. Use `assets/net/node-metrics.sh start|stop` around any load
   ([MEASUREMENT.md](references/MEASUREMENT.md)). Freeing CPU on a host that is
   not the bottleneck does not move the score — move work onto it instead.
2. **Cheap observations before deep work.** One measurement usually exposes the
   next 2–3 levers (an idle host to shift TLS to, connection churn, allowance
   drops). An hour of kernel/XDP work in the run produced 0 %.
3. **Every change must survive reboot.** All tuning below is applied by systemd
   oneshot units or config files, never by hand.
4. **Check the regulation** before replacing certificates, adding hosts to the
   request path, or changing anything the benchmarker might validate.

## Lever checklist (do in this order)

| # | Lever | Cost | Observed effect | Details |
|---|---|---|---|---|
| 1 | Stop CPU-eating daemons (keep ssh + cloud agent) | 2 min | small, removes noise | [NET-TUNE.md](references/NET-TUNE.md) |
| 2 | sysctl (backlogs, ports, buffers) + `LimitNOFILE` | 2 min | prevents collapse under load | [NET-TUNE.md](references/NET-TUNE.md) |
| 2b | Client `keepalive_timeout` from the measured gap CDF (bench fds/ports are finite) | 10 min | wrong values FAILed 2 runs (fd, then port exhaustion on the client) | [NGINX.md](references/NGINX.md#client-idle-timeout-derive-it-do-not-guess) |
| 3 | nginx: upstream keepalive, `access_log off`, h2, `reuseport`, `worker_cpu_affinity auto`, `open_file_cache`, `gzip_static` | 10 min | large; HTTP/1.1 to the client was −5 % vs h2 | [NGINX.md](references/NGINX.md) |
| 4 | Co-located nginx→app over a Unix socket; separate DB/app/nginx hosts | 15 min | 3-host split ≈ +10 %; UDS small + | [NGINX.md](references/NGINX.md) |
| 5 | **Prebuilt nginx + AWS-LC** (drop-in via systemd override) | 5 min | +5 % score; TLS hosts +10 pt idle CPU | [NGINX-AWSLC.md](references/NGINX-AWSLC.md) |
| 6 | TLS 1.3 only, X25519, session cache/tickets; ECDSA cert **only if allowed** | 5 min | ECDSA P-256 + X25519: +3 % | [NGINX.md](references/NGINX.md#tls) |
| 7 | **Spread TLS termination** across hosts: DNAT + MASQUERADE + flowtable | 15 min | the step that let 3 hosts share TLS CPU | [TLS-LB.md](references/TLS-LB.md) |
| 8 | NIC IRQ → CPU pinning, XPS, `pfifo_fast`, irqbalance off | 5 min | +2 % | [NET-TUNE.md](references/NET-TUNE.md) |
| 9 | Worker ↔ CPU ↔ NIC queue alignment (`SO_INCOMING_CPU`, built into the prebuilt nginx) | 0 min with lever 5 | +1–2 % | [NGINX-AWSLC.md](references/NGINX-AWSLC.md) |
| 10 | Watch cloud NIC allowances; compress large responses | 5 min | prevented a 15 % "mystery" regression | [NET-TUNE.md](references/NET-TUNE.md#cloud-nic-allowances) |
| 10b | **Long inter-host RTT** (emulated regions): per-route `initcwnd`/`initrwnd` + larger default `tcp_rmem`; nginx `client_body_buffer_size` ≥ typical upload; cap every disk cache | 10 min | one RTT off 80–100 KB responses; best run +~6 %; prevented disk-full FAILs | [DEAD-ENDS.md](references/DEAD-ENDS.md#third-run-real-contest-4--2-vcpu-emulated-regions-100-ms-inter-host-rtt) |
| 11 | App-side: in-memory state + local WAL, long-poll empty polls, app terminates TLS itself | hours | largest wins overall | [APP-PATTERNS.md](references/APP-PATTERNS.md) |
| 12 | **Only if the front host is the bottleneck** (lowest idle, high soft%): prebuilt patched kernel (ENA XDP_TX on shared rings, batched doorbells) + XDP L4 LB instead of iptables TLS-LB | 20 min + reboot | front host −60 % doorbells, softirq 33→27 %, idle 4–7 → 14–16 %; +3 % score when weights were shifted to it, 0 % while another host was the limit | [KERNEL-XDP.md](references/KERNEL-XDP.md) |

## Measured dead ends — do not spend contest time

| Tried | Result |
|---|---|
| `napi_defer_hard_irqs=2` + `gro_flush_timeout=50us` | IRQs 37k/s → 0.1k/s but −5 % (latency) |
| raw-table `NOTRACK` for proxied flows | no change |
| GRO off on the front host | no change |
| XDP L4 load balancer on the **stock** ENA driver | −2 %: ENA XDP needs `2 × queues ≤ max queues` → halves queues (the patched kernel in lever 12 removes this) |
| `PREEMPT_NONE` alone | no measurable change |
| `preempt=none` boot param | no effect without `CONFIG_PREEMPT_DYNAMIC` |
| HTTP/1.1 instead of h2 to the client | −5 % |
| Go app terminating TLS itself (crypto/tls) | −10 % (Rust + rustls/aws-lc-rs was +4 %) |
| `Cache-Control: max-age` on static files | workload-dependent: −35 % in one phase, + later — always A/B |
| Home-made TLS edge proxy replacing nginx | −4 % handshakes/s; 0-point run from h2-cancel bugs before it was dropped |
| Read-local replica cluster across the TLS hosts | −8 %: replication CPU competes with TLS |
| TLS session cache/ticket tuning when the client never resumes | no effect — check `$ssl_session_reused` first |
| DB streaming standby on the app hosts | −45 %: WAL replay pinned the app hosts' disk IOPS |
| `remote_apply` (synchronous) replication on every commit | score halved |
| `proxy_request_buffering off` | FAIL |

Details and numbers: [DEAD-ENDS.md](references/DEAD-ENDS.md).

## Reference files

- [MEASUREMENT.md](references/MEASUREMENT.md) — `node-metrics.sh`, perf/strace recipes, A/B protocol without the official bench.
- [NGINX.md](references/NGINX.md) — config skeleton (main, upstream, TLS, static, SSE, UDS).
- [NGINX-AWSLC.md](references/NGINX-AWSLC.md) — download/verify/install the prebuilt binary; what the patches do; rebuild fallback.
- [TLS-LB.md](references/TLS-LB.md) — splitting TLS termination over N hosts with netfilter; weights; flowtable.
- [NET-TUNE.md](references/NET-TUNE.md) — IRQ/XPS/qdisc, sysctl, daemons, cloud NIC allowances.
- [APP-PATTERNS.md](references/APP-PATTERNS.md) — transferable app designs and the Go→Rust decision.
- [KERNEL-XDP.md](references/KERNEL-XDP.md) — prebuilt patched kernel + XDP LB: measured CPU effect, when it turns into score, safe one-shot install.
- [DEAD-ENDS.md](references/DEAD-ENDS.md) — everything that did not work, with numbers.
- `assets/` — `nginx-awslc/` (build script, patches, systemd override), `net/` (scripts, units, sysctl, metrics), `kernel/` (patch, config, build/install), `xdp/` (XDP LB source + loader).
