# Patched Kernel + XDP Load Balancer (front-host packet CPU)

**What it does:** cuts the front host's packet-processing CPU when that host
forwards a share of TLS connections to other hosts (TLS-LB). **Measured
effect: it worked as designed on CPU; the score did not move because the
front host was not the bottleneck at the time.** Use it when `node-metrics.sh`
shows the *front host* as the lowest-idle host with high `soft%`.

## Measured effect (same environment hold, same app build, ≥2 runs per arm)

| Metric (front host) | stock kernel + iptables DNAT | patched kernel + XDP LB |
|---|---|---|
| ENA doorbells per transmitted packet | ≈ 1 : 1 (4.83M doorbells) | 1.92M for 4.83M packets (−60 %) |
| softirq share | 33 % | 27 % |
| idle CPU, weights skewed toward front (27/64 local) | 4–7 % | **14–16 %** |
| idle CPU, default weights (21/64 local) | 29 % | 34 % |
| `pps_allowance_exceeded` per run | 500–2600 | lower |
| score, skewed weights | 2.62M / 2.66M | 2.71M / 2.73M (+3 %) |
| score, default weights | 2.69M / 2.57M / 2.62M / 2.58M | 2.56M / 2.56M (bottleneck elsewhere) |

Read: the patch frees ~10 pt of front-host CPU. Whether that becomes score
depends on giving the front host more work (more TLS buckets) **and** on the
other hosts not being the limit. In the run the app host stayed saturated,
so the freed CPU only paid when weights were shifted toward the front host.

## Why the stock driver cannot do it

On stock ENA (Linux 6.17):

- `ena_xdp_allowed()` requires `2 × num_io_queues ≤ max_num_io_queues` (XDP_TX
  gets dedicated queues) and MTU ≤ 3498. With 2 queues per small instance, XDP
  forces **1 queue** + RPS → the queue halving costs more than XDP saves
  (measured −2 %).
- `ena_xdp_xmit_frame()` rings a doorbell for every `XDP_TX` frame.

`assets/kernel/0001-ena-xdp-shared-tx-batched-doorbell.patch` changes both:

- module parameter `ena.xdp_shared_tx=Y` (default on): `XDP_TX` uses the
  regular Tx rings under the netdev Tx queue lock (excluded from BQL), so the
  queue count stays at its maximum;
- `XDP_TX` frames are written without a doorbell, and one doorbell is rung at
  the end of the NAPI poll.

Other config changes: `PREEMPT_NONE`, `LOCALVERSION=-isucon`, `localmodconfig`
from an EC2 c5 host (ENA, NVMe, virtio-net, Xen blkfront built in);
mitigations / LSM / audit unchanged. `PREEMPT_NONE` alone gave no measurable
gain.

## Prebuilt packages (no build on contest day)

Release `kernel-6.17.13-isucon-r1` on `mazrean/agent-skills`:

| Asset | Use |
|---|---|
| `linux-image-6.17.13-isucon_6.17.13-1_amd64.deb` | the kernel + modules |
| `xdp-lb.o` | compiled XDP program (`assets/xdp/xdp-lb.c`) |
| `SHA256SUMS` | checksums (also pinned below) |

Headers are not published (only needed for out-of-tree modules; rebuild if required).

The published image is a rebuild of the measured kernel: same source
(6.17.13), config, and patch; only build user/host/timestamp were fixed
(`isucon@build`, 2026-10-30 00:00 UTC) so no local information ships. The
measured build booted and ran on EC2; **this rebuild itself has not been
boot-tested** — the one-shot install below is what makes a first boot safe.

Targets: x86-64 Ubuntu 24.04 on AWS Nitro (ENA). Other clouds with virtio-net
boot (driver built in) but gain nothing from the ENA patch. Hosts whose
hardware needs a driver that `localmodconfig` dropped will not boot — the
one-shot boot below makes that recoverable.

```sh
TAG=kernel-6.17.13-isucon-r1
BASE=https://github.com/mazrean/agent-skills/releases/download/$TAG
mkdir -p kdeb && cd kdeb
for f in linux-image-6.17.13-isucon_6.17.13-1_amd64.deb xdp-lb.o; do curl -fsSLO "$BASE/$f"; done
sha256sum -c <<'SUMS'
2464e6a530890ca0c4a8a198ffe4bf05e531277820cac99b50a5e72bb86ec466  linux-image-6.17.13-isucon_6.17.13-1_amd64.deb
c07d2c5f0d713f2782642f3e19d95ee495a8af90ea6376830b787714b84f2049  xdp-lb.o
SUMS
```

## Install safely (one-shot boot)

```sh
HOST=isu1 assets/kernel/install.sh ./kdeb     # dpkg -i, keep GRUB_DEFAULT=stock, grub-reboot once, wait for new boot_id
# measure (node-metrics.sh + XDP on/off below); if it wins and survives a full reboot test:
HOST=isu1 assets/kernel/install.sh --default
# undo at any time:
HOST=isu1 assets/kernel/install.sh --stock
```

Rules: pre-approve cloud-API reboot before trying; have
`aws ec2 reboot-instances` + `get-console-output` ready; never do this in the
last 2 hours; make it the default only after a full reboot test of all hosts.

## XDP load balancer

`assets/xdp/xdp-lb.c` is a stateless L4 LB in the driver: the client's
`source port` is hashed into 64 buckets; buckets map to the front host
(`XDP_PASS` → local nginx) or to another host (rewrite to
`front:sport → target:443`, `XDP_TX`; replies are rewritten back). It replaces
iptables DNAT + MASQUERADE + flowtable from TLS-LB.

```sh
sudo install -D -m 644 kdeb/xdp-lb.o /usr/local/lib/isucon/xdp-lb.o
# on each target host: route back to the front with the XDP MTU
sudo ip route replace <front_ip>/32 dev <if> mtu lock 3498 advmss 3458
# on the front host (needs bpftool: linux-tools-$(uname -r) or linux-tools-common)
sudo SELF=<front_ip> CLIENT=<bench_ip> TARGETS="<host3_ip>:27 <host2_ip>:10" assets/xdp/xdp-lb.sh on
sudo assets/xdp/xdp-lb.sh off      # back to iptables TLS-LB
```

- MTU drops to 3498 on the front host while XDP is on (ENA XDP limit).
- Bucket counts are the TLS weights (out of 64; the rest stay local).
- Skewing too much toward the front host produced validation errors once —
  A/B every weight change.
- The prebuilt `xdp-lb.o` was compiled with zig 0.15.2 (clang 20, BPF target)
  from the published source. The object measured in the run was a clang 18
  build of the same program on the host; the prebuilt one was not loaded
  through the verifier on a host before publishing. If `bpftool prog load`
  rejects it, build on the host: `sudo apt-get install -y clang libbpf-dev &&
  clang -O2 -g -target bpf -I/usr/include/x86_64-linux-gnu -c xdp-lb.c -o xdp-lb.o`.

## Rebuild (only for another kernel version or hardware)

```sh
W=/path/to/work assets/kernel/build.sh     # ~6 min on 32 cores; needs flex bison libelf-dev libssl-dev bc dwarves
```

For another base kernel, regenerate the config on the target
(`cp /boot/config-$(uname -r) .config; make localmodconfig`) and re-apply the
patch (it touches `ena_xdp.c/h`, `ena_netdev.c/h` only).
