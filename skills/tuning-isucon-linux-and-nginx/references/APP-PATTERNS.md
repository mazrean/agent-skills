# Transferable App Patterns

Domain-independent designs that produced the largest gains, with the traps hit
while building them. The problem-specific logic (matching, scoring) is not
here — only shapes that recur across ISUCON problems.

## 1. Everything in memory, persistence off the request path

Shape that went from 1.8k to 288k in one rewrite:

- Load every table into memory at boot and on `POST /initialize`. One process,
  one lock (`sync.Mutex` / `parking_lot::Mutex`) is fine to start; measure
  lock hold time before splitting it.
- Each mutation appends a **row snapshot** (table, key, full row) to a queue.
  A single writer flushes batches (`INSERT ... ON DUPLICATE KEY UPDATE`, dedup
  by key) every `PERSIST_INTERVAL` (1 s was best: more dedup, fewer statements).
- Later step: replace runtime MySQL writes with a **local append-only WAL**
  file (length-prefixed records, buffered writer, `Flush` per batch, `fsync` on
  SIGTERM). At boot: load MySQL, replay the WAL, then write the replayed state
  back to MySQL and truncate the WAL. MySQL then sits idle during the run and
  its host can take TLS load (see TLS-LB).
- `POST /initialize`: stop the writer (hold its lock), drop the queue,
  truncate the WAL, reload. Otherwise a stale flush lands after reset.
- systemd: `KillSignal=SIGTERM`, `TimeoutStopSec=60`, `Restart=always`, and
  the DB unit ordered before the app. Reboot test = reboot every host at
  once, then compare response hashes (`md5sum` of a few GET responses) and row
  counts before/after.
- Store aggregates instead of history when the API only needs aggregates
  (per-entity location totals instead of every coordinate): large write and
  memory reduction.

## 2. Polling endpoints that return "nothing yet"

When clients poll and most answers are empty, every empty answer triggers an
immediate re-poll that costs both sides CPU.

- **Long-poll**: hold an empty response until something changes or a timeout
  (seconds, well under the client timeout), then answer. Wake **K waiters per
  event**, not everyone (thundering herd) — K was tuned by A/B.
- Do not hold responses whose emptiness changes the client's evaluation of
  you (holding a "my rides" list made clients rate slower and cost 5 %).
- Effect in the run: 36万 → 64万 (the largest single app change after the
  in-memory rewrite). Whether it is allowed is a regulation question — the
  response must stay correct and within documented latency.

## 3. Server-sent events / notification streams

- Build the event payload **at the moment of the state change** and queue the
  bytes; building it at send time leaks later state into earlier events.
- Keep a **per-subscriber generation counter**. When a subscriber reconnects
  (or a new logical session starts), bump the generation; an old connection
  that sees a newer generation stops instead of consuming the next event.
  Without this, an old stream took the first event of a new session and the
  client never saw it (a validation error that only appeared under load).
- End the stream cleanly when the protocol says the session is done.

## 4. External calls with retries

- Retry with an idempotency key if the external service supports it.
- Do **not** retry in parallel with the original request — a race can apply
  the operation twice even with keys.

## 5. Lock hold time

- Measure max/avg hold time of the global lock (wrap Lock/Unlock with
  timestamps behind an env flag). Replacing an all-pairs sort with a per-entity
  best pick took one hold from 19 ms to ≤ 4 ms.
- Precompute sets the hot path scans (e.g. "free entities") instead of
  filtering the whole table under the lock.

## 6. Go → Rust: when it pays

- Go app host CPU idle 4–10 % → Rust port 39–43 % at the same load
  (tokio + hyper 1, single `parking_lot::Mutex`, `lto = "fat"`,
  `codegen-units = 1`, `panic = "abort"`). The score only moved once something
  else used that freed CPU (the app then terminated its own TLS share with
  `tokio-rustls` + `aws-lc-rs`: +4 % vs nginx in front of it on the same host).
- A full port by a subagent took ~20 minutes for ~3k lines of Go when the Go
  code was treated as the spec, with a byte-compatible WAL so either binary can
  replay the other's log. Start such ports **before T−3h** or not at all.
- Go tuning before porting: `GOGC=400` (fewer GCs with an in-memory dataset),
  avoid `encoding/json` reflection on hot paths, pre-marshal static responses.
- Go terminating TLS itself (crypto/tls) was **slower** than nginx in front
  (−10 %); only the Rust/aws-lc-rs stack beat nginx.

## 7. Static files served by the app

When the app terminates TLS itself, it must reproduce nginx's static behaviour
exactly (same headers, `gzip_static` choice by `Accept-Encoding`, SPA
fallback, `ETag`/`Last-Modified` if the client revalidates). Load `public/`
into memory at boot and diff every file's headers and body against nginx
before switching.

## 8. Replicated in-memory read model across hosts

From a 4-host contest with ~100 ms between hosts and mandatory cross-host
read-your-writes. This shape was the base of the 17k → 112k climb:

- DB triggers append changed rows to a changelog table. One host tails it by
  snapshot (`pg_current_snapshot()` diff, single statement, no gaps), applies
  to memory and pushes numbered batches to the peers. A peer applies in order
  and pulls missing sequence numbers from the pusher's buffer. It rebuilds on
  an epoch change.
- **Leases bound by the sender's clock.** A peer serves from memory only while
  `min(receive time, send time) + 1 s` holds. The pusher may skip an
  unresponsive peer only after the last lease it could have granted has
  expired, plus clock skew. A lease extended by a late heartbeat caused
  "must not be visible" integrity FAILs.
- **Watermark-gated reads** instead of per-write acks: a peer answers a
  read only when its applied watermark ≥ the request's arrival time (slack
  0). Waits were 1–144 ms p50.
- Writes return only after their own cycle is applied, and pushed or
  watermarked. 4xx responses skip that barrier.
- Ship blobs (images) only to regions where someone can see them, and
  drop to "fetch on demand" when the queue overflows.
- **Differential oracle before any official run:** replay a long random write
  sequence (1,500 steps) and diff every GET between the DB path, the
  primary's memory and a replica's memory. Diff 0 or no run.
- Full-state dumps to peers must be rare and bounded. A 625k-row dump
  repeated mid-run killed the score.
