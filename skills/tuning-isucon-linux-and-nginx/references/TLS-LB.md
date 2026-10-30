# Spreading TLS Termination Across Hosts (netfilter, no extra proxy)

The benchmarker connects to one address. Once TLS dominates that host's CPU,
let the kernel forward a share of **new** :443 connections to nginx (or an app
that terminates TLS itself) on the other hosts. No user-space proxy, no extra
hop for the payload's TLS work.

```
client ──► front:443 ─┬─ (p0) local nginx
                      ├─ (p1) DNAT → host2:443   (MASQUERADE: replies return via front)
                      └─ (p2) DNAT → host3:443
```

## Install

```sh
sudo install -m 755 assets/net/tls-lb.sh /usr/local/bin/isucon-tls-lb.sh
sudo install -m 644 assets/net/isucon-tls-lb.service /etc/systemd/system/
echo 'LB_TARGETS="10.0.0.3:1.3 10.0.0.2:0.5"' | sudo tee /etc/isucon/tls-lb.env   # private IPs:weight
echo 'LB_SELF_WEIGHT=0.75' | sudo tee -a /etc/isucon/tls-lb.env
sudo systemctl daemon-reload && sudo systemctl enable --now isucon-tls-lb
```

Run it only on the front host. Every target must serve the same vhost and
certificate on :443.

What the script does (idempotent, survives reboot via the unit):

- `net.ipv4.ip_forward=1`
- `nat/PREROUTING` → chain with one `statistic --mode random` DNAT rule per
  target, probabilities computed so that weights are exact (conditional
  probability over the remaining share), matching only `--ctstate NEW`
- `nat/POSTROUTING` MASQUERADE toward each target, so replies come back
  through the front host (the client only knows the front address)
- an **nftables flowtable** for forwarded flows: after the handshake, packets
  of established flows bypass most of netfilter (software fast path). This
  removed most per-packet forwarding cost (forwarded datagrams fell to ~24k per
  41 s, i.e. only handshake/FIN packets).

## Choosing weights

1. Run once with equal weights; read `node-metrics.sh` idle% per host.
2. Shift weight toward hosts with idle CPU — whichever direction idle% points. Do not starve the app host: in the
   run, sending only 15 % of TLS to the app host was −5 % versus 30–50 %.
3. Final observed split (front : DB host : app host) = 0.75 : 1.3 : 0.5, with
   the app terminating its own share of TLS.
4. Seed weights from per-host **full-handshake capacity** measured with a
   synthetic client (`oha --disable-keepalive`), not from CPU %.
5. When one host stays the least idle for 2+ runs, the next official run
   changes only the weights. In a second run the app host sat at ~10 % idle
   versus 25–40 % elsewhere for six runs while weights were changed late and
   bundled with other changes; the score plateaued.

## Costs and limits

- **All egress still leaves through the front host's NIC** (MASQUERADE). The
  front host hits cloud NIC bandwidth/pps allowances first — watch
  `bwOutDrop`/`ppsDrop`, compress large static files. Each forwarded flow
  crosses the front's ENI twice (in and out for both legs): the front hit
  `pps_allowance_exceeded` at ~65–84k rx+tx pps. A patched kernel or XDP cuts
  CPU, not packets; the cure is a higher self-weight for local termination.
- **Hung SYNs at the end of a run.** With clients reusing source ports
  (`tcp_tw_reuse`), new SYNs collided with conntrack `TIME_WAIT` entries (120 s
  default) on the DNAT front: a burst of `dial tcp …:443: i/o timeout` at run
  end, 8 errors, −18 %. `MASQUERADE --random-fully` plus
  `net.netfilter.nf_conntrack_tcp_timeout_time_wait=5` → 0 errors next run.
- `iptables` here is iptables-nft on recent Ubuntu; the flowtable is plain
  `nft`. Both are restored by the unit at boot.
- Persistent connections stick to the host chosen at connect time; SSE/long-poll
  connections therefore stay where they landed.
- An XDP version (stateless L4 LB in the driver) was built and measured: on
  stock ENA it forces a single queue and loses; with a patched kernel it gained
  3 % — not worth it on contest day (see DEAD-ENDS).
