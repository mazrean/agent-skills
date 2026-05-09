# Measurement: alp, pt-query-digest, pprof, Netdata

ISUCON is decided by **how fast you read the right signal**. Every reasonable team uses the same three tools — the difference is fluency.

## The Three-Tool Loop

Run these in order after every benchmark:

1. **`alp`** — which HTTP endpoints consumed the most total time?
2. **`pt-query-digest`** — which SQL queries consumed the most total time?
3. **`pprof`** — within the slowest endpoints, which Go functions are hot?

If alp's #1 endpoint matches a pt-query-digest top-3 query, the answer is in the SQL. If not, the answer is CPU/algorithm — go to pprof.

## alp (nginx access log profiler)

Source: https://github.com/tkuchiki/alp

Reads the nginx access log (LTSV or JSON) and aggregates per-endpoint stats: count, total/avg/p99 response time, total bytes.

**Basic command:**

```bash
sudo cat /var/log/nginx/access.log | alp ltsv --sort=sum -r
```

`--sort=sum` (sum of response times) is the right default. `--sort=avg` is useful only after the obvious heavy endpoints are dealt with.

**Path normalization** is critical — without it, `/api/chair/abc` and `/api/chair/xyz` are counted as different endpoints. Use `-m`:

```bash
sudo cat /var/log/nginx/access.log | alp ltsv --sort=sum -r \
  -m "/api/chair/[a-z0-9-]+,/api/app/rides/[a-z0-9-]+"
```

Or persist the patterns in `alp.yml`:

```yaml
sort: sum
reverse: true
matching_groups:
  - /api/chair/[a-z0-9-]+
  - /api/app/rides/[a-z0-9-]+
  - /api/owner/chairs/[a-z0-9-]+
```

Then `alp ltsv --config alp.yml < /var/log/nginx/access.log`.

**Reading the output:** the columns of interest are `COUNT`, `SUM` (total time), `AVG`, `P99`, `URI`. Focus on the row with the largest `SUM` — that is where time is being spent in aggregate, regardless of per-call cost.

## pt-query-digest (MySQL slow query analyzer)

Part of `percona-toolkit`. Aggregates the slow query log, normalizing literal values into placeholders.

**Basic command:**

```bash
sudo pt-query-digest /var/log/mysql/slow.log | less
```

**Reading the output:** the top section is the "Profile" — a ranked list of normalized queries by total query time. Each entry has:

- `Rank` and `Query ID`
- `Response time` (sum) and `%` of total
- `Calls` (count)
- The normalized query

Below the profile, each query has a detailed section with:

- A representative example query
- `EXPLAIN` (if `--explain` is passed)
- Histogram of response time distribution

**Tactic:** the top one or two queries usually account for 50–90% of time. If they share a table, that table needs an index. If they are in a hot loop, you have an N+1.

**For full output to file:**

```bash
sudo pt-query-digest /var/log/mysql/slow.log > /tmp/slow.report
```

## pprof (Go profiler)

For Go applications, add to `main.go`:

```go
import _ "net/http/pprof"

go func() {
    log.Println(http.ListenAndServe(":6060", nil))
}()
```

(Behind a build tag or env var so you can disable it for the final benchmark.)

**During a benchmark run, capture a 30s CPU profile:**

```bash
go tool pprof -http=:8080 http://localhost:6060/debug/pprof/profile?seconds=30
```

This launches a web UI on `:8080` with flame graph, top, source view, and call graph.

**For text-mode top:**

```bash
go tool pprof -text -seconds=30 http://localhost:6060/debug/pprof/profile
```

**Other profiles:**

```bash
go tool pprof http://localhost:6060/debug/pprof/heap        # memory
go tool pprof http://localhost:6060/debug/pprof/goroutine   # goroutine count
go tool pprof http://localhost:6060/debug/pprof/mutex       # mutex contention
```

**Reading flame graphs:** width = total time spent in the function (including callees). Look for unexpectedly fat columns — `runtime.mallocgc` (allocation pressure), `syscall.Syscall` (I/O), `database/sql.(*DB).query` (DB roundtrips).

## Netdata (live system metrics)

Auto-installs a web UI on port `:19999`. Useful for confirming **which instance and which subsystem** is the bottleneck during a live run.

Watch:

- **CPU per core** — if MySQL pegs one core, the DB is single-query-bound; if it pegs all cores, it is throughput-bound.
- **Disk I/O** — if `iowait` is high, you have unindexed scans or fsync pressure.
- **Network** — high outbound on the app box during a run = response payloads are big (consider gzip, image sizing, or fewer fields).
- **MySQL queries/sec** plotted alongside app CPU shows whether you are app-bound or DB-bound at a glance.

## Other Useful Commands

```bash
# Live process view, sorted by CPU
htop

# Per-second CPU/mem/network/disk
sar -u 1
sar -r 1
sar -n DEV 1

# Watch MySQL connections live
mysql -e "SHOW PROCESSLIST"
mysql -e "SHOW ENGINE INNODB STATUS\G" | less

# Inspect what a process is doing right now
sudo strace -p <pid> -c -f
```

## Custom: Annotated SQL (LayerX 2024 trick)

Wrap your `database/sql` driver to inject `/* file:line:func */` into every query as a comment. The comment passes through to the slow query log unchanged, so `pt-query-digest` shows you the **call site of every slow query**.

Source: https://zenn.dev/layerx/articles/3bd55b77e047c4

Sketch (pseudocode):

```go
type AnnotatingConn struct {
    driver.Conn
}

func (c *AnnotatingConn) QueryContext(ctx context.Context, q string, args []driver.NamedValue) (driver.Rows, error) {
    _, file, line, _ := runtime.Caller(2)
    annotated := fmt.Sprintf("/* %s:%d */ %s", file, line, q)
    return c.Conn.(driver.QueryerContext).QueryContext(ctx, annotated, args)
}
```

This single trick saves enormous time when grepping for "where does this query come from".

## Measurement Discipline

1. **Truncate logs before each run.** A mixed log gives mixed signals.
2. **Same benchmark settings each run.** Otherwise you cannot compare scores.
3. **Capture the alp/pt-query-digest output to a file with the score and commit hash.** You will want the trail when deciding what to revert.
4. **Disable measurement overhead before the final benchmark.** `pprof` HTTP, `long_query_time = 0`, and full nginx logging together can cost 5–15% of the score.
