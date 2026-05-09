# Design Dimensions

Five orthogonal axes. Pick one option per axis and tie the choice to a row from `BASELINE.md`. A dimension with no baseline-driven motivation is left at "no change".

## 1. Topology

Where each process runs across the 2–3 provided instances. This is the most expensive decision to revisit later — get it right early.

| Option | When to pick | Risks |
|--------|-------------|-------|
| **All-on-one** (default) | Toy or first-hour state. Never a final design. | App and DB compete for CPU. |
| **App + DB split** (app on isu1, DB on isu2, isu3 idle) | DB CPU > 70% in baseline; app CPU < 50%. | Network round-trip latency between app and DB; DSN env var must change everywhere. |
| **Multi-app + DB split** (app on isu1+isu2 behind nginx, DB on isu3) | App CPU saturated even after DB split; nginx idle. | In-process caches diverge — see dimension 3. |
| **App + DB + cache** (app on isu1+isu2, DB on isu3, Redis on isu3 alongside DB or on isu1) | Multi-app + you need shared mutable cache. | Adds a SPOF; Redis tuning becomes a hot spot. |
| **Pinned-endpoint** (one CPU-heavy endpoint on a dedicated instance) | One endpoint dominates pprof and is CPU-bound (bcrypt, image processing). | Routing config more complex; uneven load. |

**Decision input from baseline:** which instance/subsystem peaks at >80% CPU first.

**Constraints that bite:**
- Listen address: when DB moves to isu3, every app needs DSN pointed at isu3's *private* IP, not localhost.
- Firewall / security group: confirm port 3306 (MySQL) and 6379 (Redis) are open between the relevant instances.
- nginx upstream: `keepalive 64; proxy_http_version 1.1; proxy_set_header Connection "";` — without these you exhaust TIME_WAIT under load.

ASCII diagram convention used in `DESIGN.md`:

```
isu1: nginx (80) + app-go (8080)
isu2: app-go (8080)
isu3: mysql (3306) + redis (6379)

client → isu1:80 → upstream{isu1:8080, isu2:8080} → isu3:3306 / isu3:6379
```

## 2. Storage

How data is held at rest. The reference is always MySQL; the question is what to *change*.

| Option | When to pick | Risks |
|--------|-------------|-------|
| **MySQL, indexes only** | Slow queries dominate, schema is otherwise sane. | Indexes hurt writes — drop unused for write-heavy tables. |
| **MySQL, schema reshape** (denormalize, change types, add summary tables) | Top query is fundamentally too expensive even with index. | Requires updating every write path; benchmarker must still see the same response. |
| **MySQL + Redis sidecar** (Redis for hot read keys, MySQL of record) | Read QPS on a small key set is the bottleneck and the data is single-key by access pattern. | Cache invalidation correctness; Redis becomes a SPOF. |
| **MySQL + in-memory derived state** (loaded on `/initialize`, mutated in process) | Read-mostly with a stable seed set; multi-app not yet in topology. | Writes from one instance invisible to others — pairs with sticky routing. |
| **Replace MySQL with SQLite** (per-instance file) | Read-only or near-read-only data, single-app topology. | Multi-app cannot use it without replication. Rare but historically winning on some problems. |
| **Append-only WAL + periodic flush** | Write-heavy log-style endpoint where read tolerates eventual consistency. | Crash recovery design must be explicit; reboot test will catch a bad implementation. |

**Decision input from baseline:** read/write ratio per hot table from `pt-query-digest`, plus `iowait` from Netdata.

**Schema-change checklist:**
- Run the new DDL against a copy of the seed; confirm `/initialize` completes within budget.
- `EXPLAIN` every top-5 query against the new schema.
- Write a migration in `webapp/sql/init.sql` (or wherever the project's reset script reads from) — not as an interactive `mysql` session. The benchmarker's reset hook will undo interactive changes.

## 3. Cache and consistency

Only relevant if storage decisions did not eliminate the need. Pick the cheapest option that survives the topology.

| Option | When to pick | Risks |
|--------|-------------|-------|
| **In-process, immutable** (`sync.Once` populated map) | Master tables (categories, settings) — written rarely or never. | None significant. |
| **In-process, mutable with `sync.RWMutex` / `sync.Map`** | Hot mutable data on a *single-app* topology. | Becomes wrong as soon as you add a second app instance. |
| **Sticky routing by user-id** (`hash $cookie_session` in nginx) | Multi-app + user-scoped state. | Imbalanced load if one user is much hotter than others. |
| **Shared via Redis** | Multi-app + cross-user shared state. | Adds a network hop; pool exhaustion under load. |
| **Per-request memoization only** | Repeated computation within one handler call. | Negligible payoff vs. effort — usually not worth a dedicated decision. |

**Cache invalidation rules** (write these into `CACHE.md` of the produced skill):

1. Every write path lists the keys it invalidates.
2. Stale read after write is a benchmarker failure — when in doubt, write-through, not write-back.
3. `/initialize` clears every in-process cache. **Always.** Forgetting this is a top reboot-test failure.
4. Warmup runs synchronously on app start, before `ListenAndServe`. Lazy first-request fill loses the first 10s of the benchmark.

## 4. Algorithmic / endpoint redesign

For each endpoint in alp's top-5, classify the win:

| Classification | Pattern | Reference |
|----------------|---------|-----------|
| **Index** | Slow query with `type: ALL` or `Using filesort`. | `winning-isucon/OPTIMIZATION-PATTERNS.md` §1 |
| **N+1** | Same query repeated in a loop, identifiable by high `Calls` in pt-query-digest. | §2 |
| **Bulk write** | Per-row INSERT loop on a write-heavy endpoint. | §3 |
| **In-memory pre-computation** | Endpoint computes the same derived value per request that depends only on data loaded at init. | §4–5 |
| **Static via nginx** | Endpoint serves an asset that should never have been routed through the app. | §6 |
| **Domain-specific algorithm** | The endpoint's computation can be replaced by a fundamentally different data structure (heap, KD-tree, precomputed table). | §10 |
| **Async / queue** | Write that does not need read-after-write consistency within the request. | (custom; see consistency rules below) |

**Per-endpoint output in `DESIGN.md`:**

```
### GET /api/foo (alp #2: 12.4s sum, 380 calls, p99 280ms)

Current shape:
  - Joins users + posts, returns latest 20 posts
  - N+1 on user lookup per post

Proposed shape:
  - Single JOIN with sqlx.In, returns same JSON
  - Add INDEX (created_at DESC) on posts
  - Estimated win: pt-query-digest #1 disappears (3.2s → ~0.4s)

Verification:
  - curl GET /api/foo before+after, diff JSON keys + array length
  - EXPLAIN shows type=range, key=created_at_idx
```

## 5. Deploy and reboot survival

The least glamorous dimension and the one that scores 0 if neglected.

| Item | Decision |
|------|----------|
| systemd unit | One unit per app instance, `Wants=mysql.service`, `After=mysql.service`, `Restart=on-failure`, `User=isucon`. |
| Env vars | DSN, Redis URL, listen port — sourced from a single `/home/isucon/env.sh` so swapping topologies edits one file. |
| Cache warmup | Synchronous, blocking, before `ListenAndServe`. Listed in `DEPLOY.md`. |
| `/initialize` idempotency | Drops in-process caches, re-applies any DDL not in `init.sql`, completes within budget. |
| Log rotation | `make rotate` truncates nginx + slow log before each run. Cron not required during the contest. |
| Reboot test | A literal `sudo reboot` per instance, wait, run benchmark. Documented in `DEPLOY.md` as the *last* verification step. |

**Reboot-survival checklist** (cross-reference `winning-isucon/COMMON-PITFALLS.md` §1):

- [ ] Every service `systemctl is-enabled` returns `enabled`.
- [ ] No DSN, host, or path is hard-coded to a value that only existed in the last shell session.
- [ ] In-memory state has a deterministic warmup path that runs on every start.
- [ ] No `/tmp` files referenced by the app that were created with `touch` interactively.
- [ ] No cron job that exists only in your shell history.
