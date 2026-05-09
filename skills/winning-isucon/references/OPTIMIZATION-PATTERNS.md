# Optimization Patterns

The same patterns recur in nearly every ISUCON. Learn them once and apply them as templates.

## 1. MySQL Indexes

The cheapest, highest-yield change. Almost every problem ships with a `schema.sql` that has only PRIMARY KEYs.

**Workflow:**

1. From `pt-query-digest`, take the top query.
2. Run `EXPLAIN` on it. Look for `type: ALL` (full table scan) or `Using filesort` / `Using temporary`.
3. Build an index covering the WHERE columns first, then ORDER BY.
4. Re-run EXPLAIN. Confirm `type: ref` or `range` and the index appears under `key`.

**Composite index rule of thumb:**

```sql
-- For:  WHERE user_id = ? AND created_at > ? ORDER BY created_at DESC
CREATE INDEX idx_user_created ON posts (user_id, created_at);
```

Order matters: equality columns first, then range/sort columns.

**Where to put the DDL:** the safest place is at the bottom of `schema.sql` or in `webapp/sql/init.sql` so the benchmarker's data-reset hook runs them. Adding indexes via interactive `mysql` works during the contest but does not survive `init.sh` re-running. **Verify by running the init script yourself before the final benchmark.**

**Watch out for:**

- Too many indexes hurt write throughput. Drop unused ones for write-heavy tables.
- `VARCHAR(255)` indexes on UTF-8 can blow past the 3072-byte index limit. Use prefix indexes `(col(64))` if needed.
- After heavy ALTERs, run `ANALYZE TABLE` so the optimizer has fresh statistics.

## 2. N+1 → Bulk Fetch

A single page that calls `SELECT` once per row in a parent set is the canonical ISUCON kill. Three solutions, in order of simplicity:

### 2a. `IN (...)` clause with `sqlx.In`

```go
ids := []int{1, 2, 3, 4, 5}
q, args, err := sqlx.In("SELECT * FROM users WHERE id IN (?)", ids)
q = db.Rebind(q)
var users []User
err = db.Select(&users, q, args...)
```

Then build a `map[int]User` and look up by parent id in your handler.

### 2b. `JOIN`

```sql
SELECT p.*, u.name AS user_name
FROM posts p
JOIN users u ON u.id = p.user_id
WHERE p.created_at > ?
ORDER BY p.created_at DESC
LIMIT 20;
```

In Go with `sqlx`, define a flat struct with `db:"user_name"` tags. Faster when you need fields from both tables and avoids a second roundtrip.

### 2c. Preload + map

When the parent set is small but the per-row query is complex:

```go
posts := getRecentPosts(db)
userIDs := lo.Uniq(lo.Map(posts, func(p Post, _ int) int { return p.UserID }))
users := getUsersByIDs(db, userIDs)
userByID := lo.KeyBy(users, func(u User) int { return u.ID })
// then join in memory while serializing the response
```

## 3. Bulk INSERT

Convert per-row `INSERT` loops into one statement:

```go
// Bad
for _, c := range conditions {
    db.Exec("INSERT INTO conditions (...) VALUES (?, ?, ?)", c.A, c.B, c.C)
}

// Good — sqlx NamedExec on a slice
_, err = db.NamedExec(
    `INSERT INTO conditions (a, b, c) VALUES (:a, :b, :c)`,
    conditions,
)
```

Or build the SQL by hand:

```go
values := make([]string, 0, len(rows))
args := make([]any, 0, len(rows)*3)
for _, r := range rows {
    values = append(values, "(?, ?, ?)")
    args = append(args, r.A, r.B, r.C)
}
q := "INSERT INTO t (a,b,c) VALUES " + strings.Join(values, ",")
db.Exec(q, args...)
```

A single 1000-row bulk insert can be 50–100x faster than 1000 single inserts.

## 4. In-Memory Cache

For data that is read often and written rarely.

### Single-process, immutable

```go
var (
    categoriesOnce sync.Once
    categoriesByID map[int]Category
)

func getCategoryByID(id int) Category {
    categoriesOnce.Do(func() {
        rows := []Category{}
        db.Select(&rows, "SELECT * FROM categories")
        m := map[int]Category{}
        for _, c := range rows {
            m[c.ID] = c
        }
        categoriesByID = m
    })
    return categoriesByID[id]
}
```

### Single-process, mutable with sync.Map / RWMutex

```go
type sessionStore struct {
    mu sync.RWMutex
    m  map[string]Session
}

func (s *sessionStore) Get(k string) (Session, bool) {
    s.mu.RLock()
    defer s.mu.RUnlock()
    v, ok := s.m[k]
    return v, ok
}

func (s *sessionStore) Set(k string, v Session) {
    s.mu.Lock()
    defer s.mu.Unlock()
    s.m[k] = v
}
```

### Multi-process (across instances): Redis or Memcached

Once you split DB and app, in-process caches diverge between app instances. Use Redis/Memcached as the shared layer, or **sticky-route** by user-id at the nginx layer so each user always hits the same app instance.

## 5. Cache Warmup on Startup

The reboot test re-runs the benchmark right after `systemctl start`. If your cache fills lazily on first request, the early seconds of the benchmark are slow.

```go
func main() {
    db = openDB()
    warmCache(db)  // synchronous — block startup until cache is warm
    http.ListenAndServe(":8080", router)
}

func warmCache(db *sqlx.DB) {
    // SELECT * FROM categories, fill categoriesByID
    // SELECT * FROM users WHERE last_active > NOW() - INTERVAL 1 DAY, fill sessionStore
}
```

## 6. Static Files via nginx

Move CSS/JS/images out of the app:

```nginx
location /static/ {
    alias /home/isucon/webapp/public/;
    expires 1d;
    add_header Cache-Control "public, max-age=86400";
    access_log off;  # do not count static in alp
}
```

Restart nginx, confirm 200s, confirm Content-Type is right.

## 7. Connection Pool Tuning

```go
db.SetMaxOpenConns(50)
db.SetMaxIdleConns(50)
db.SetConnMaxLifetime(0)
```

For HTTP clients to external services or other instances, **always** reuse a single `*http.Client` with a configured `Transport`:

```go
var httpClient = &http.Client{
    Timeout: 5 * time.Second,
    Transport: &http.Transport{
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 100,
        IdleConnTimeout:     90 * time.Second,
    },
}
```

## 8. DB Split (3-instance topology)

Default: app + DB on isu1, isu2/isu3 idle.

After: app on isu1 + isu2, DB on isu3.

**Steps:**

1. On isu3, edit `/etc/mysql/mysql.conf.d/mysqld.cnf`:
   ```ini
   bind-address = 0.0.0.0
   ```
2. Grant remote access:
   ```sql
   CREATE USER 'isucon'@'%' IDENTIFIED BY 'isucon';
   GRANT ALL ON isuride.* TO 'isucon'@'%';
   FLUSH PRIVILEGES;
   ```
3. Update DSN env var on isu1 (and isu2 once added) to point at isu3's private IP.
4. Restart app, run benchmark.
5. Stop MySQL on isu1: `sudo systemctl stop mysql && sudo systemctl disable mysql`. Frees CPU and RAM for the app.

Common mistake: forgetting to update the DSN on isu2 when adding the second app instance — silent fallback to localhost MySQL on isu2 = 0 throughput from that box.

## 9. nginx Upstream Load Balancing

On the gateway box (often isu1 keeps nginx):

```nginx
upstream app {
    server 192.168.0.11:8080;
    server 192.168.0.12:8080;
    keepalive 64;
}

server {
    listen 80;
    location / {
        proxy_pass http://app;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
    }
}
```

The `keepalive` + `proxy_http_version 1.1` + empty `Connection` is required to avoid TIME_WAIT explosion under load.

## 10. Algorithmic Wins (the big jumps)

The textbook patterns above usually take you to mid-pack. Reaching the top 10 nearly always requires an **algorithmic** change to a domain-specific function.

Examples from past ISUCONs:

- **ISUCON14**: matching algorithm changed from random to nearest-chair → score 21k → 30k.
- **ISUCON11**: condition-graph reduced to 24h sliding window via timestamp range, dropping 500-row scans per call.
- **ISUCON9**: pre-compute campaign-applied prices instead of recomputing per render.

The pattern: read the manual carefully for the **business intent** of each endpoint. The reference implementation expresses it correctly but inefficiently. Replace it with an equivalent that uses the right data structure (heap, KD-tree, precomputed table, sorted index) for that intent.

## Order of Operations Summary

For a typical 8-hour run:

| Hour | Action | Typical score band |
|------|--------|--------------------|
| 0-1 | Recon, baseline, ToolingMakefile, log setup | 1k–3k |
| 1-2 | Indexes for top slow queries | 3k–8k |
| 2-3 | N+1 → IN/JOIN, bulk INSERT | 8k–15k |
| 3-4 | DB split, in-memory cache for masters | 15k–25k |
| 4-5 | Algorithmic rewrite of hottest endpoint | 25k–40k |
| 5-6 | Multi-app, nginx upstream, sticky routing | 40k–55k |
| 6-7 | Targeted micro-tuning (pool sizes, GC, allocations) | 55k–60k |
| 7-8 | Endgame: disable logs, reboot test, lock | final |
