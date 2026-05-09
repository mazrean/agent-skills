# Example Designs

Three worked examples. Each shows the five-dimension decision tied to a baseline number, then the resulting topology diagram. These are illustrative — adapt to your own measurements.

## Example 1: ISUCON14 (isuride)

A ride-hailing app: client matching, chair coordinate streaming, ride state machine, notification SSE.

### Baseline (hypothetical, post-recon)

| Tool | Top finding |
|------|------------|
| alp #1 | `GET /api/app/notification` sum 24s, p99 1.2s |
| alp #2 | `POST /api/chair/coordinate` sum 19s, count 28k |
| pt-query-digest #1 | `SELECT * FROM rides WHERE user_id = ?` 18s total, 8000 calls |
| pt-query-digest #2 | `SELECT * FROM chair_locations WHERE chair_id = ? ORDER BY created_at DESC LIMIT 1` 11s |
| pprof leaf | `database/sql.(*DB).query` 38% — confirms DB-bound |
| Netdata | isu1 mysql cpu 92% across 2 cores; isu2/isu3 idle |

### Decisions

| Dimension | Decision | Tied to |
|-----------|----------|---------|
| 1. Topology | App on isu1+isu2, MySQL on isu3, Redis on isu3 | Netdata: MySQL pegs isu1 |
| 2. Storage | MySQL + composite indexes; `chair_locations` summarized into a `latest_chair_location` table updated on coordinate write | pt-query-digest #2 |
| 3. Cache | `chairsByID` immutable in-process; `latestRideByUserID` Redis (shared across apps) | Multi-app + cross-instance writes |
| 4. Algorithm | Notification: replace N+1 over rides+chairs with one `IN (?)` per call; matching: replace random match with nearest-chair via in-memory KD-tree of free chairs | alp #1, plus the published ISUCON14 algorithmic win |
| 5. Deploy | `EnvironmentFile=/home/isucon/env.sh` for DSN/Redis URL; reboot test scripted | reboot survival required |

### Topology diagram

```
isu1: nginx + app-go        (80, 8080)
isu2: app-go                (8080)
isu3: mysql + redis         (3306, 6379)

  client → isu1:80 → upstream{isu1:8080, isu2:8080}
                          │
                          ├→ isu3:3306 (mysql)
                          └→ isu3:6379 (redis: latestRideByUserID, sessions)
```

### Apply-skill expected at

`.claude/skills/applying-isucon-arch-isuride/`

## Example 2: ISUCON13 (isupipe)

Live-streaming chat / livestream / reactions / NG words.

### Baseline (hypothetical)

| Tool | Top finding |
|------|------------|
| alp #1 | `GET /api/livestream/:id/livecomment` sum 31s |
| alp #2 | `GET /api/livestream/:id/reaction` sum 14s |
| pt-query-digest #1 | `SELECT * FROM livecomments WHERE livestream_id = ? AND ...` 22s |
| pt-query-digest #2 | DNS query (PowerDNS) — recurring per icon URL build |
| pprof leaf | `net.LookupHost` 18% — DNS in critical path |
| Netdata | nginx idle on isu1; mysql 70% on isu1; pdns chatty |

### Decisions

| Dimension | Decision | Tied to |
|-----------|----------|---------|
| 1. Topology | Single-app on isu1, MySQL on isu2, dedicated PowerDNS+image-cache on isu3 | DNS hot in pprof; isu3 unused |
| 2. Storage | MySQL on isu2; livecomment_count summary table to avoid full scans for per-livestream tally | pt-query-digest #1 |
| 3. Cache | Icon image bytes cached on disk on isu1 with `If-Modified-Since` short-circuit; NG word regex compiled once into in-process | DNS + image bytes are read-heavy, write-rare |
| 4. Algorithm | Reaction tally precomputed per livestream and updated on insert; NG-word filter switched from per-comment regex compile to compiled-once map lookup | pt-query-digest #1, pprof |
| 5. Deploy | `pdns_recursor` config locked; `If-Modified-Since` honored by app handler; reboot test scripted | reboot survival |

### Topology diagram

```
isu1: nginx + app-go + image cache    (80, 8080)
isu2: mysql                           (3306)
isu3: pdns + pdns_recursor            (53)

  client → isu1:80 → app:8080
                       ├→ isu2:3306 (mysql)
                       └→ isu3:53 (DNS for icon URL building, low rate)
```

## Example 3: private-isu

Image-board mini-Twitter. Used for practice.

### Baseline (hypothetical)

| Tool | Top finding |
|------|------------|
| alp #1 | `GET /` (timeline) sum 8s |
| alp #2 | `GET /image/:id.jpg` sum 6s, served by app |
| pt-query-digest #1 | `SELECT * FROM posts ORDER BY created_at DESC LIMIT 20` 5s |
| pt-query-digest #2 | per-post `SELECT * FROM users WHERE id = ?` 4s (N+1) |
| pprof leaf | `image/jpeg.Encode` 22% — JPEG re-encoding on upload |
| Netdata | iowait 30% on isu1; nginx idle; disk under pressure |

### Decisions

| Dimension | Decision | Tied to |
|-----------|----------|---------|
| 1. Topology | Single instance (private-isu only ships one) | regulation |
| 2. Storage | Add INDEX `(created_at DESC)` on posts; move uploaded images out of the DB onto disk under nginx | pt-query-digest #1, alp #2 |
| 3. Cache | `usersByID` immutable in-process for the user join; comments-count per post precomputed | N+1 |
| 4. Algorithm | Image upload: stop re-encoding JPEG, store original; nginx serves `/image/*` from disk via `try_files` | pprof leaf, alp #2 |
| 5. Deploy | systemd unit + `/initialize` clears caches, re-extracts images from DB to disk if needed | reboot survival |

### Topology diagram

```
isu1: nginx (with /image/ → /home/isucon/webapp/image/) + app-go + mysql

  client → isu1:80 ┬→ /image/* → static disk
                    └→ /        → app:8080 → mysql:3306
```

## Reading the examples

The pattern is the same in all three:

1. **The topology decision falls out of which instance is bottlenecked**, not from a love of distributed systems.
2. **Schema and cache choices are driven by a specific query** in pt-query-digest, not by general "we should add Redis" reasoning.
3. **Algorithmic wins exist in every problem** but rarely in the same shape twice — read the manual carefully for the *intent* of each endpoint.
4. **Reboot survival is part of every design**, not an afterthought.

Use these as a reference for the level of specificity your own `DESIGN.md` should reach. Vague designs ("use cache for hot data") cannot be turned into a runnable apply-skill.
