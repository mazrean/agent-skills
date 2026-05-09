# Output Skill Template

The exact structure of the apply-skill emitted in phase 4. The executing session will read this skill cold — embed every fact it needs.

## Directory layout

```
.claude/skills/applying-isucon-arch-<problem-slug>/
├── SKILL.md
└── references/
    ├── TOPOLOGY.md
    ├── SCHEMA.md
    ├── CACHE.md
    ├── ENDPOINTS.md
    └── DEPLOY.md
```

`<problem-slug>` is lowercase, hyphens-only, ≤64 chars (counting the full skill name including the `applying-isucon-arch-` prefix).

## SKILL.md template

```markdown
---
name: applying-isucon-arch-<slug>
description: Applies the architecture redesign decided in docs/isucon-arch/DESIGN.md to <problem name>. Use when ready to execute the planned topology, schema, cache, and endpoint changes for this ISUCON problem. Assumes phase-0/1/2/3 of designing-isucon-architecture have already produced CONSTRAINTS.md, BASELINE.md, DESIGN.md.
---

# Applying ISUCON Architecture: <problem name>

Mechanically applies the redesign captured in `docs/isucon-arch/DESIGN.md`. Each phase has a verification step; do not advance until it passes.

**Use this skill when** the design is approved and the contest clock is running. **Do NOT** improvise — if reality contradicts the plan, stop, edit `DESIGN.md`, regenerate this skill via `designing-isucon-architecture`, then resume.

## Pre-flight

- [ ] Current branch clean and committed (rollback target).
- [ ] `docs/isucon-arch/DESIGN.md` and `CONSTRAINTS.md` present and read.
- [ ] One full baseline benchmark recorded in `BASELINE.md`.

## Phase A — Topology

Apply the instance roles and network plumbing from [TOPOLOGY.md](references/TOPOLOGY.md).

Verification: `curl http://<isu1-private-ip>/health` (or first reachable endpoint) returns 200 from each app instance, and `mysql -h <db-ip> -u isucon -p` connects from each app instance.

## Phase B — Schema

Apply the DDL deltas from [SCHEMA.md](references/SCHEMA.md). Run them via `webapp/sql/init.sql` (or the project's reset script), not via interactive `mysql`.

Verification: `EXPLAIN` each top-5 query and confirm the predicted `key` and `type` from `SCHEMA.md`.

## Phase C — Cache

Wire the caches and warmup from [CACHE.md](references/CACHE.md). Add the `/initialize` clear path in the same commit.

Verification: restart the app, confirm warmup completes; call `/initialize`, confirm caches reset; load-test the cached endpoints, confirm read-after-write semantics on the listed write paths.

## Phase D — Endpoints

Apply the per-endpoint changes from [ENDPOINTS.md](references/ENDPOINTS.md). One commit per endpoint where possible. Run the benchmarker after every two or three endpoints — do not batch all of them and run once.

Verification: per-endpoint curl diff (before vs after) against a recorded baseline response.

## Phase E — Deploy and reboot

Apply the systemd / nginx / log-rotation changes from [DEPLOY.md](references/DEPLOY.md). Then run the reboot test as the *final* verification.

Verification: `sudo reboot` on each instance, wait for SSH, run benchmarker, confirm score within 5% of the last good run.

## Rollback

If any phase regresses the score, `git revert` the commit and re-run the benchmark to confirm recovery. Do not attempt to debug forward under contest pressure.

## Reference Files

- [TOPOLOGY.md](references/TOPOLOGY.md)
- [SCHEMA.md](references/SCHEMA.md)
- [CACHE.md](references/CACHE.md)
- [ENDPOINTS.md](references/ENDPOINTS.md)
- [DEPLOY.md](references/DEPLOY.md)
```

## TOPOLOGY.md template

```markdown
# Topology

## Instance roles

| Instance | Private IP | Role | Listen ports |
|----------|-----------|------|--------------|
| isu1 | 192.168.0.11 | nginx + app-go | 80, 8080 |
| isu2 | 192.168.0.12 | app-go | 8080 |
| isu3 | 192.168.0.13 | mysql + redis | 3306, 6379 |

## Diagram

(ASCII diagram from DESIGN.md)

## Env vars

`/home/isucon/env.sh`:

```bash
export ISUCON_DB_HOST=192.168.0.13
export ISUCON_DB_PORT=3306
export ISUCON_DB_USER=isucon
export ISUCON_DB_PASSWORD=isucon
export ISUCON_DB_NAME=<db>
export REDIS_URL=redis://192.168.0.13:6379
```

Source from each app's systemd unit via `EnvironmentFile=/home/isucon/env.sh`.

## nginx upstream

`/etc/nginx/sites-available/isucon`:

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
    location /static/ {
        alias /home/isucon/webapp/public/;
        expires 1d;
        access_log off;
    }
}
```

## DB remote-access

On isu3:
```ini
# /etc/mysql/mysql.conf.d/mysqld.cnf
bind-address = 0.0.0.0
```

```sql
CREATE USER 'isucon'@'%' IDENTIFIED BY 'isucon';
GRANT ALL ON <db>.* TO 'isucon'@'%';
FLUSH PRIVILEGES;
```

## Connection pools

App-side (Go example):

```go
db.SetMaxOpenConns(50)
db.SetMaxIdleConns(50)
db.SetConnMaxLifetime(0)
```

HTTP-to-internal:
```go
&http.Transport{MaxIdleConns: 100, MaxIdleConnsPerHost: 100, IdleConnTimeout: 90 * time.Second}
```
```

## SCHEMA.md template

```markdown
# Schema deltas

Apply via `webapp/sql/init.sql` so `/initialize` reapplies them.

## DDL

```sql
-- For: SELECT * FROM rides WHERE chair_id = ? ORDER BY created_at DESC LIMIT 1
CREATE INDEX idx_rides_chair_created ON rides (chair_id, created_at);

-- For: SELECT * FROM chair_locations WHERE chair_id = ? AND created_at >= ? ORDER BY created_at
CREATE INDEX idx_chair_locations_chair_created ON chair_locations (chair_id, created_at);

-- ... one per top-5 query
```

## EXPLAIN expectations

For each query above:

| Query | Before (type / key / rows) | After (type / key / rows) |
|-------|---------------------------|---------------------------|
| SELECT ... rides ... | ALL / NULL / 50000 | ref / idx_rides_chair_created / 12 |
| ... | | |

Run after applying:

```bash
mysql -e "EXPLAIN <query>" <db>
```
```

## CACHE.md template

```markdown
# Cache layer

## Caches in this design

| Cache | Scope | Storage | TTL | Warmup | Cleared on `/initialize` |
|-------|-------|---------|-----|--------|--------------------------|
| chairsByID | per-app | in-process map | none (immutable seed) | yes | yes |
| sessionByToken | per-app, sticky-routed | sync.Map | 5m idle | no | yes |
| rideStateByID | shared | Redis | 10s | no | yes (FLUSHDB on init) |

## Warmup procedure (Go sketch)

```go
func warmCache(db *sqlx.DB) {
    var chairs []Chair
    db.Select(&chairs, "SELECT * FROM chairs")
    for _, c := range chairs {
        chairsByID[c.ID] = c
    }
    // ... other caches
}

func main() {
    db = openDB()
    warmCache(db)              // synchronous; block until ready
    http.ListenAndServe(":8080", router)
}
```

## Invalidation matrix

For every write endpoint, the keys it must invalidate.

| Endpoint | Caches written / invalidated |
|----------|------------------------------|
| POST /api/rides | rideStateByID[ride_id] |
| PATCH /api/rides/:id | rideStateByID[id] |
| POST /api/chair/coordinate | (none — coordinates are not cached) |

## /initialize handler additions

```go
func postInitialize(c echo.Context) error {
    // existing reset logic
    chairsByID = map[string]Chair{}
    sessionByToken = sync.Map{}
    redis.FlushDB(ctx)
    warmCache(db)
    return c.JSON(200, ...)
}
```
```

## ENDPOINTS.md template

```markdown
# Endpoint changes

One section per endpoint changed. Listed in alp-baseline rank order.

---

## #1 GET /api/app/notification

**Baseline**: alp sum 18.4s, p99 920ms. pt-query-digest #1 ("SELECT * FROM rides WHERE user_id = ?") accounts for 14s.

**Classification**: N+1 + missing index.

**Plan**:
1. Add `idx_rides_user_created ON rides (user_id, created_at DESC)`.
2. Replace per-ride `SELECT chair WHERE id=?` with a single `WHERE id IN (?)` and a `map[string]Chair`.
3. Reuse the in-process `chairsByID` cache from CACHE.md when available.

**Code sketch**:

```go
rides := getUserRides(ctx, userID)
chairIDs := lo.Map(rides, func(r Ride, _ int) string { return r.ChairID })
chairs := getChairsByIDs(ctx, chairIDs)        // single IN query, or cache hit
chairByID := lo.KeyBy(chairs, func(c Chair) string { return c.ID })
// build response
```

**Verification**:

```bash
# Before: capture baseline
curl -s http://isu1/api/app/notification -H "Cookie: app_session=..." > /tmp/before.json

# After change:
curl -s http://isu1/api/app/notification -H "Cookie: app_session=..." > /tmp/after.json
diff <(jq -S . /tmp/before.json) <(jq -S . /tmp/after.json)   # must be empty

# EXPLAIN check
mysql -e "EXPLAIN SELECT * FROM rides WHERE user_id='X' ORDER BY created_at DESC" <db>
# Expect: type=ref, key=idx_rides_user_created
```

**Estimated win**: pt-query-digest #1 disappears; alp sum on this endpoint 18.4s → ~3s.

---

## #2 POST /api/chair/coordinate

(... etc, one section per top-5)
```

## DEPLOY.md template

```markdown
# Deploy and reboot

## systemd unit

`/etc/systemd/system/isuride-go.service`:

```ini
[Unit]
Description=isuride go
Wants=mysql.service
After=mysql.service

[Service]
User=isucon
WorkingDirectory=/home/isucon/webapp/go
EnvironmentFile=/home/isucon/env.sh
ExecStart=/home/isucon/webapp/go/isuride
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable on each app instance:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now isuride-go.service
```

## Deploy script

`/home/isucon/deploy.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
cd /home/isucon/webapp/go
go build -o isuride .
sudo systemctl restart isuride-go.service
```

## Log rotation

Before each benchmark:

```bash
sudo truncate -s 0 /var/log/nginx/access.log /var/log/mysql/slow.log
```

For the final benchmark, also disable verbose logging:

```bash
sudo sed -i 's|access_log /var/log/nginx/access.log|access_log off|' /etc/nginx/nginx.conf
sudo systemctl reload nginx
sudo mysql -e "SET GLOBAL slow_query_log = 0;"
```

## /initialize sanity

```bash
time curl -X POST http://localhost:8080/initialize
# Must complete within the regulation budget (typically ≤30s)
```

## Reboot test (final verification — do NOT skip)

For each instance, in sequence:

```bash
sudo reboot
# wait for SSH to come back (typically 30–60s)
ssh isuN 'systemctl is-active isuride-go.service mysql.service nginx.service'
# all three must report "active"
```

Then from the contest portal, run the benchmarker. The score must be within 5% of the last good run. If not, inspect:

```bash
ssh isu1 'sudo journalctl -u isuride-go.service -n 100 --no-pager'
```

Common failures and recoveries are listed in `winning-isucon/COMMON-PITFALLS.md` §1.
```

## Embedding rule

If a fact is needed by the executing session, it lives in the apply-skill — not "see the codebase". Acceptable cross-references:

- Specific file paths in the codebase: ✅ (e.g. "edit `webapp/go/handlers/notification.go:getNotification`").
- Cross-skill links to `winning-isucon/*` for procedure: ✅.
- "Read the code and figure out what to do": ❌. Embed the relevant excerpt or rewrite the plan to be concrete.
