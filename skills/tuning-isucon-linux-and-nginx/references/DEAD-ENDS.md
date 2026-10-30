# Measured Dead Ends

Everything below was implemented and A/B-measured (two or more runs per arm,
same deployed build). Numbers are scores of the observed workload; the
direction is what transfers. Skip these on contest day unless the
situation is clearly different.

## Kernel / NIC

| Change | Before → after | Why |
|---|---|---|
| `napi_defer_hard_irqs=2`, `gro_flush_timeout=50us` | 2.63M/2.59M → 2.51M/2.44M (−5 %) | IRQs 37k/s → 0.1k/s and +1.5 pt idle, but added latency dominates |
| raw `NOTRACK` for front↔app proxied flows | 2.57M/2.68M → 2.52M/2.57M | conntrack was ~3 % of the host; flowtable already removed forwarding cost |
| GRO off on the front host | 2.59M → 2.57M | no effect (TSO unsupported on that NIC anyway) |
| qdisc swap alone | — | doorbells ≈ packets (no `xmit_more` batching): cost is the MMIO doorbell, not the qdisc |
| `preempt=none` | no effect | needs `CONFIG_PREEMPT_DYNAMIC`, absent in the cloud kernel |
| `cpuidle-haltpoll` | not tried | 2 vCPUs were HT siblings; polling would slow the sibling |

## XDP load balancer on the stock ENA driver

A stateless XDP L4 LB was built and verified. On the **stock** ENA driver XDP
requires `2 × queues ≤ max_num_io_queues` → with 2 queues it forces **1 queue**
+ RPS (and MTU ≤ 3498), and `XDP_TX` rings a doorbell per frame. Same weights:
2.60M → 2.54M. The patched kernel removes both limits and does cut CPU — see
[KERNEL-XDP.md](KERNEL-XDP.md) for numbers and when that turns into score.

## nginx / HTTP

| Change | Result |
|---|---|
| HTTP/1.1 to the client instead of h2 | 255k/271k vs ~288k (−5 %) |
| `gzip_static off` | no difference in CPU, but egress ↑ (later hit NIC allowance) |
| `timer_resolution 10ms`, `proxy_buffering off` on all `/api/` | slightly worse |
| upstream `keepalive 16384` + `worker_connections 65536` | no gain over 256 |
| `no-store` on all static files | −20 % (614k) |
| 304 revalidation for assets | worse (887k/866k vs ~915k) |

## App

| Change | Result |
|---|---|
| Go `crypto/tls` terminating TLS on the app host | −10 % |
| Holding a list endpoint (not just empty polls) | −5 % (clients rated slower) |
| Parallel retries to an external API | no gain, double-apply risk |
| Score-rate-based scheduling heuristics | worse than simple distance-based |
