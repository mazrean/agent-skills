# Local Correctness and Pseudo-Bench (first hour)

With a congested queue (30 min per official result was emulated), an agent
needs its own answer to "is this build correct, and is it faster?" before any
official slot. The second observed run built the pieces below in the first
hour, without reading benchmarker source; they carried the rest of the day.
Everything is derived from the manual, the API spec, the reference app, and
**your own access logs of one real bench run**.

## 1. Oracle-differential checker (`check`)

- **Oracle:** a second copy of the reference app with its **own** DB copy, on
  a host off the request path (or local), plain HTTP. It is the spec.
- **Checker self-test:** a third copy (reference vs reference). Any diff
  there is a checker bug, not an app bug — run it once after every checker
  change.
- **Assertions** are model-based (expected values computed from the request
  sequence) **and** differential (every 200 body from target and oracle
  diffed, with generated IDs mapped positionally to logical names, `null` ≡
  `[]`, order-only differences on tie-sorted lists as WARN). Assert the model
  on both target and oracle; an oracle failure means the model is wrong.
- **Cover the error paths the bench will validate:** every auth rejection
  (expired, wrong key, wrong alg, missing claims, wrong role/tenant → 401/403),
  404 on unknown IDs, 400 on malformed uploads, state transitions (finished,
  disqualified), paging boundaries, and "a read during a write returns
  exactly the old or the new state". The bench's own access log tells you
  which of these it exercises.
- **Auth without the real secret:** generate a test keypair; point the app
  under test (and the oracle) at the test public key through config. Never
  trust the test key in production — run checks against a shadow stack (§3).
- **Initial data:** recompute a few reference queries directly from the
  initial DB dump and compare; cheap proof that an in-memory loader is exact.
- Budget: ~40–75 s per run; ~170–200 checks was enough to gate a full
  in-memory rewrite and a language port.

## 2. Load generator (`load`)

- Same client code as `check`, driven by a scenario mix fitted to the real
  run's access log: per-endpoint request counts within a few % of the real
  run (here pseudo 2,844 vs real 2,617 on the reference app).
- Mirror the bench's **adaptive ramp** if it has one (workers added as
  responses get faster) — that is what exposed client-limit failures.
- Enforce the real client's limits: `ulimit -n 1024`, default ephemeral port
  range, same keepalive behaviour, ~2 % request cancellations, long idle
  connections. Without them the pseudo-bench passes builds the bench FAILs
  (OBSERVED-BARRIERS A8, B17).
- Never on a host that serves traffic (B18). If every host serves, run it
  from the local machine through a firewall rule scoped to your IP, logged in
  `NOTES.md` for cleanup; mind the local `ulimit` and the home router's NAT
  (cap connections).
- Report **CPU per 1,000 points** (or per 1,000 requests of the fixed mix),
  not CPU % — the load scales with app speed.

## 3. Shadow-stack preflight (before every official slot that changes the stack)

One script, one line of output (`PREFLIGHT: PASS` / `FAIL (<reasons>)`):

1. Start a **shadow copy of the live layout on alternate ports** on every
   host: the deployed app binary and the live nginx binary with a copied
   config, test key, separate data/WAL dir, logs off. Production units,
   ports, keys and data are never written.
2. Probe a logged-in request through each shadow front.
3. Run `check` against one shadow front, then `load` against all shadow
   fronts concurrently for ~30 s, with per-host metrics around it.
4. FAIL on: start failure, any check failure, any truncation / EOF / reset /
   5xx / decode error, RSS growth above a threshold.
5. Tear everything down in a `trap`; hold the environment lock, ≤ 5 min.

It catches breakage, not scores. Pair it with an auto-revert guard for the
official run ("after run N: if errors > 0, redeploy the previous best").

## 4. Queue emulator (rehearsal only)

A `bench-queue.sh enqueue|status` that waits `QUEUE_WAIT` seconds, then takes
the environment lock and benchmarks **whatever is deployed at that moment**,
recording enqueue time, start time and the deployed state read from the hosts.
Make it mirror the real portal: one pending job per team and no exact start
time, or the habits it trains (stacked jobs, deploying just before a known
fire time) will not transfer (BENCH-LOOP.md).

## 5. Browser / E2E check

A headless-browser run (e.g. Playwright) of the main user flows through the
**public** address, compared with the oracle, covers the organisers'
post-contest browser check and any internet-path breakage. It creates data:
run it before the final official runs, not after.
