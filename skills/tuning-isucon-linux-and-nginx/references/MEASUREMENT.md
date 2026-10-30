# Measurement Without Waiting for the Bench

On contest day the benchmark queue is congested; a score arrives minutes after
you enqueue, and scores move ±5–12 % between identical runs. Decide infra
changes from **per-host cost**, and use the official bench to confirm batches.

## Per-host counters around any load

`assets/net/node-metrics.sh` snapshots `/proc/stat`, NIC byte counters, cloud
NIC allowance drops, and TCP counters on every host, then prints deltas:

```sh
export HOSTS="isu1 isu2 isu3"
assets/net/node-metrics.sh start
#   ... one official bench run, or a synthetic load (below) ...
assets/net/node-metrics.sh stop
host         usr%   sys%  soft%  idle%   txMB/s   rxMB/s bwOutDrop   ppsDrop accept/s retrans/s
isu1         26.4   19.1   36.8   17.7     48.2     11.0         0      1200     2100        12
isu2         49.8   25.3   19.6    5.3      9.1     20.4         0         0      730         1
isu3         34.6   21.3   19.0   25.1     30.5      7.9         0         0     1400         4
```

How to read it:

- **Lowest idle% host is the bottleneck.** Work that frees CPU elsewhere does
  not raise the score; move load *to* the hosts with idle (TLS weights, static
  serving, background jobs).
- **soft% high** on the front host → packet processing; see NET-TUNE (IRQ/XPS)
  and TLS-LB (flowtable).
- **accept/s high on an app host** behind nginx → upstream keepalive is broken
  (observed: 30k passive opens in 41 s from nginx→app).
- **bwOutDrop / ppsDrop > 0** → the cloud NIC is shaping you; see
  NET-TUNE "Cloud NIC allowances". This explains score *decay* on unchanged code.
- **retrans/s rising** with drops → you are past the NIC budget.

## A/B protocol

- Alternate baseline and variant **inside one hold of the environment**:
  `B V B V` (not `B B V V`), same deployed app build, record the build id.
- Compare the per-host idle% and the bottleneck host's usr+sys per request,
  then the score. Two runs per arm is the minimum; with a congested queue,
  prefer synthetic load for infra-only changes.
- One change per pair. Revert immediately on a loss.

## Synthetic load for infra-only changes (no official bench needed)

TLS, nginx, kernel, and NIC changes do not depend on business logic. Measure
them with a generic load generator against a cheap endpoint and static files,
from a host that is not in the request path (or from the bench-side host when
allowed):

```sh
# h2 + TLS handshakes + small responses (oha: cargo install oha / prebuilt binary)
oha -z 30s -c 200 --http2 --insecure https://<front>/                 # static + TLS
oha -z 30s -c 200 --http2 --insecure --disable-keepalive https://<front>/api/<cheap-endpoint>  # handshake cost
```

Wrap each run with `node-metrics.sh` and compare CPU per request
(`(usr+sys+soft)% × cores / req/s`). This is what decided the AWS-LC switch and
the nginx syscall patches before any official run.

## Profiling recipes

```sh
# where does a host's CPU go (all processes, kernel included)
sudo perf record -F 999 -a -g -o /tmp/p.data -- sleep 15
sudo perf report -i /tmp/p.data --no-children --sort comm,dso,sym --stdio | head -80

# syscall mix of one nginx worker (found the per-record getsockopt(SO_ERROR))
sudo timeout 3 strace -c -f -p "$(pgrep -f 'nginx: worker' | head -1)"

# softirq / IRQ distribution per CPU
mpstat -P ALL 5 1; grep -E 'Tx-Rx|virtio' /proc/interrupts

# cloud NIC shaping (ENA)
sudo ethtool -S "$(ip -o route show default | awk '{print $5}')" | grep allowance
```

Go app: `net/http/pprof` behind an env flag. Rust app: `perf` with
`debug = 1` in the release profile (`cargo build --release` keeps speed).

## Pitfalls observed

- A profiling build (debug symbols, perf attached) scores 10–20 % lower — never
  compare it with normal runs.
- Results measured while another agent's half-finished build was deployed were
  silently wrong. Always deploy the intended build inside the lock and log
  `sha1sum` of the deployed binary next to the numbers.
- A burst-credit window (cloud NIC) produced a +15 % "improvement" that vanished
  on consecutive runs. Run at least two in a row before believing a jump.
