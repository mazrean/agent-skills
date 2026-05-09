# Common Pitfalls

Failures that turn a high-scoring run into a 0, or that silently cap your score. Read this list before T−2h.

## 1. Reboot Test Failure (Score → 0)

After the contest, organizers run `sudo reboot` on every instance and re-run the benchmark. If your app does not start, or starts but immediately errors, your score is 0 regardless of what you achieved during the contest.

**Common causes:**

- App not enabled in systemd: `sudo systemctl enable isuride-go.service`
- MySQL not enabled or comes up after the app: ensure `Wants=mysql.service` and `After=mysql.service` in the unit file.
- App listens before MySQL is ready: add a small retry loop on connect.
- Hard-coded localhost DSN on instance #2 after a DB split.
- `/tmp` files referenced from app code that exist only because you `touch`ed them manually.
- nginx config syntax error not caught by reload — the running process keeps old config until reboot, then fails.
- A cron job or one-shot script (e.g., a manual cache warmup) that exists only in your shell history.

**Defense:** run `sudo reboot` on each instance at T−90min, wait, run the benchmarker, confirm it scores normally. Do this with at least 60 minutes of buffer.

## 2. Spec Violation (Score → 0)

The benchmarker validates response shape, status codes, ordering, side-effects. A correctness regression mid-run causes the run to fail with 0 points.

**Common causes:**

- Caching responses without invalidating on the right write paths.
- Returning stale data because a write went to one app instance and the cache lives on another.
- Floating-point or rounding differences after rewriting computations.
- Reordering JSON arrays where order is part of the contract.
- Race conditions when removing transactions that you assumed were defensive.

**Defense:** after every refactor, run the benchmark in short mode if available; otherwise read the benchmarker's error output carefully. The first sign of trouble is usually a single `validation error` in the bench log — do not ignore it just because the score still looks ok.

## 3. Logging Overhead

You enabled `long_query_time = 0` and the full nginx access log for measurement. If you forget to disable them before the final benchmark, you lose 5–20% of your score to log writes.

**Defense at T−45min:**

```bash
# nginx
sudo sed -i 's|access_log /var/log/nginx/access.log ltsv|access_log off|' /etc/nginx/nginx.conf
sudo systemctl reload nginx

# MySQL
sudo mysql -e "SET GLOBAL slow_query_log = 0;"
# or set long_query_time = 999 in config and restart
```

Also disable the `pprof` HTTP handler — even when not actively profiled, `runtime.SetCPUProfileRate` and goroutine sampling have a small cost.

## 4. Cache Inconsistency Across App Instances

You added an in-memory cache, then split traffic across isu1 and isu2. A write goes to isu1, isu1 invalidates its cache, isu2 still serves stale.

**Symptoms:** intermittent benchmarker validation failures that disappear on retry.

**Fixes (in order of preference):**

1. Move the cache to Redis/Memcached so both instances share it.
2. Use sticky routing by user-id (`hash $cookie_session` in nginx) so each user always hits the same instance.
3. Push invalidation events between instances (HTTP POST on write).
4. Drop the cache for that data and rely on a DB index instead.

## 5. Cold Cache at Reboot

Your app fills its cache on first request. The benchmarker hits 100 endpoints in the first second after restart. The first 10 seconds are catastrophically slow, the run scores 30% less than your last contest run.

**Defense:** warm the cache **synchronously during startup**, before `ListenAndServe`. Block startup until the cache is ready. The benchmarker tolerates a slightly longer startup; it does not tolerate a slow first 10 seconds.

## 6. innodb_flush_log_at_trx_commit

Setting this to `0` (or `2`) speeds up writes dramatically but loses up to 1s of committed transactions on a crash. ISUCON's reboot test is graceful (`reboot`, not power-pull), so this is generally safe — **but read the year's regulation**. Some editions add an explicit data-durability check.

## 7. Cache Key Collisions / Stale Pointers

In-memory caches that store **pointers** to mutable structs leak modifications across requests. Always store value copies, or freeze with `sync.Once` and treat as immutable.

```go
// Wrong: returns a pointer that the caller might mutate
func GetUser(id int) *User { return userCache[id] }

// Right: return by value
func GetUser(id int) User { return userCache[id] }
```

## 8. Connection Pool Exhaustion

You added a fast HTTP client to call another service. Under load, you open a fresh connection per request, run out of ephemeral ports, and the benchmarker starts timing out.

**Defense:** always reuse a `*http.Client` with `Transport.MaxIdleConnsPerHost` set ≥ expected concurrency. Same for Redis clients (`PoolSize`), MySQL (`SetMaxOpenConns`), Memcached.

## 9. The Init / Bench-Prep Hook

Most ISUCON apps have an init endpoint (`POST /initialize`) that the benchmarker calls before each run to reset state. Common mistakes:

- Initialization runs slow (>30s by spec) → benchmarker fails.
- Re-creating a table inside `/initialize` drops your indexes silently.
- A new in-memory cache that is not cleared in `/initialize` keeps stale data from the previous run.

**Defense:** treat `/initialize` as a checkpoint. Re-establish all in-memory state, run any DDL you depend on, ensure idempotency. If you add a cache, **clear it in `/initialize`**.

## 10. Benchmarker Behavior Surprises

The benchmarker simulates real users. Two patterns break naive optimizations:

- **Keep-alive across requests**: per-request work that allocates a fresh struct per request blows up the GC. Reuse `sync.Pool` for response builders.
- **Concurrency level varies during a run**: a benchmark may start with 5 workers and ramp to 50. An optimization that helps at low concurrency (e.g., naive in-process locking) can collapse at high concurrency.

**Defense:** Look at the benchmark log's per-second throughput, not just final score. A run that peaks then drops indicates contention or pool exhaustion under increasing load.

## 11. Out-of-Disk

The slow query log at `long_query_time = 0` can fill the disk in minutes during a heavy benchmark.

**Defense:** truncate logs before every run (`make rotate` in your Makefile). Watch `df -h` during the run.

## 12. Forgetting to Push to Git

You make a brilliant change, your scoreboard hits #3, you go to lunch. Someone reverts a file thinking it was the broken one. You have no commit. Your two-hour win is gone.

**Defense:** commit on every successful benchmark with a message containing the score: `feat: add idx on rides; bench=21372`. Push at least every hour. The git log doubles as your run journal.

## 13. The Manual Sometimes Hides the Win

Past ISUCONs have included clauses like "you may pre-render the X page" or "the Y endpoint may be served from a static file" that go unnoticed for the first 4 hours. Before optimizing the hard way, **read the manual one more time** at hour 2 and hour 4.
