# Host and NIC Tuning (all runtime, no rebuild)

## 1. Daemons

Stop what burns CPU or wakes up mid-run; **keep ssh and the cloud's recovery
agent** (on AWS, `amazon-ssm-agent` ships as a snap — disabling `snapd` kills
it, so leave snapd running or install the agent as a deb).

```sh
for u in unattended-upgrades ModemManager multipathd multipathd.socket udisks2 fwupd packagekit; do
  sudo systemctl disable --now "$u" 2>/dev/null || true
done
for t in apt-daily.timer apt-daily-upgrade.timer motd-news.timer man-db.timer fwupd-refresh.timer; do
  sudo systemctl mask --now "$t" 2>/dev/null || true
done
```

## 2. sysctl

`assets/net/99-isucon-sysctl.conf` → `/etc/sysctl.d/99-isucon.conf`, then
`sudo sysctl --system`:

```
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_slow_start_after_idle = 0
net.core.rmem_max / wmem_max = 16777216, *_default = 262144
net.ipv4.tcp_rmem / tcp_wmem = 4096 87380|65536 16777216
fs.file-max = fs.nr_open = 2097152
```

Also raise `LimitNOFILE=` in every service unit that accepts connections.

## 3. NIC queues ↔ CPUs

`assets/net/net-tune.sh` + `isucon-net-tune.service` (oneshot, every boot):

- stop irqbalance (it was observed putting both queues' IRQs on CPU 0)
- pin queue N's IRQ to CPU N
- XPS: CPU N transmits on queue N
- `pfifo_fast` under `mq` instead of `fq_codel`

```sh
sudo install -m 755 assets/net/net-tune.sh /usr/local/bin/isucon-net-tune.sh
sudo install -m 644 assets/net/isucon-net-tune.service /etc/systemd/system/
sudo systemctl daemon-reload && sudo systemctl enable --now isucon-net-tune
```

Combined with nginx `worker_cpu_affinity auto` + `reuseport` + the
`SO_INCOMING_CPU` patch in the prebuilt nginx, a connection's IRQ, TCP
processing, and nginx worker stay on one CPU (Linux 6.x
`reuseport_select_sock_by_hash()` prefers the listener whose
`sk_incoming_cpu` matches the CPU that handled the SYN). Each step was +1–2 %.

## 4. Cloud NIC allowances

Cloud NICs shape traffic per instance. On AWS ENA the counters are visible:

```sh
sudo ethtool -S ens5 | grep allowance_exceeded
#  bw_in_allowance_exceeded, bw_out_allowance_exceeded,
#  pps_allowance_exceeded, conntrack_allowance_exceeded, linklocal_allowance_exceeded
```

What happened in the run:

- Small instances have a baseline bandwidth plus **burst credits**. While
  credits lasted, scores were ~15 % higher; on consecutive runs credits ran
  out, `bw_out_allowance_exceeded` reached millions, retransmits and timeouts
  followed, and the drop looked like a regression of the last change.
- Fix was to cut egress: `gzip_static` for large assets (3.6 GB → 2.1 GB per
  run) and avoid `no-store` on big files.
- After bandwidth was fixed, the front host still hit **pps** allowance
  (500–2600 drops per run) — the next ceiling when one host carries all
  traffic (TLS-LB MASQUERADE).

Checklist: log these counters per run (`node-metrics.sh`), run twice in a row
before trusting a jump, and re-check limits for the contest's instance type in
the first hour.

## 5. What not to do

See [DEAD-ENDS.md](DEAD-ENDS.md): NAPI deferral, NOTRACK, GRO off, XDP on stock
ENA, custom kernels.
