# Constraint Matrix

Phase 3 validation. For each row, mark the design's status against the rule. Any RED row blocks emission of the apply-skill.

Statuses:
- **GREEN** — design fully complies; no further action needed.
- **YELLOW** — design complies but the compliance is fragile (e.g. depends on a manual step). Note the mitigation.
- **RED** — design violates the rule, or has a credible path to violating it under load.

## Matrix

| # | Rule (from regulation) | What to check in the design | Status |
|---|------------------------|----------------------------|--------|
| 1 | API URI/method must remain unchanged | Diff phase-0 endpoints inventory against the apply-skill router file. | |
| 2 | Response body shape must remain unchanged | Each `ENDPOINTS.md` row's "new shape" preserves field names, types, ordering of arrays where ordering is part of the contract. | |
| 3 | HTTP status codes preserved per endpoint | Apply-skill's per-endpoint plan lists status codes; matches phase-0 inventory. | |
| 4 | Frontend statics served byte-for-byte | Apply-skill does not modify `webapp/public/` (or equivalent). nginx config still serves it from the same prefix. | |
| 5 | `isuwari` and its dependencies untouched | No file path under `/opt/isuwari`, `/var/lib/isuwari`, `/etc/systemd/system/isuwari*` appears in the apply-skill. | |
| 6 | `isuadmin` user/permissions/login untouched | `/etc/passwd` and home directory unchanged; sudoers unchanged. | |
| 7 | `/initialize` completes within budget (≤30s typical) | Apply-skill's `DEPLOY.md` includes a timed `/initialize` measurement step. | |
| 8 | App survives `sudo reboot` and starts cleanly | `DEPLOY.md` ends with an explicit reboot test as the last verification. systemd `Wants=` and `After=` set correctly. | |
| 9 | In-memory caches initialize on every start | Apply-skill's `CACHE.md` documents synchronous warmup before `ListenAndServe`. | |
| 10 | `/initialize` clears every in-process cache | `CACHE.md` lists each cache and its clear-on-init step. | |
| 11 | Read-after-write consistency preserved per endpoint | For each cached read endpoint, every write path that touches its data invalidates the cache *before* the request returns. | |
| 12 | Initial data preserved (benchmarker seeds with it) | DDL in `SCHEMA.md` is additive (CREATE INDEX, ALTER ADD) or paired with a re-population step. No data drops without restoration. | |
| 13 | No external compute beyond regulation grants | Apply-skill does not reference external CDNs, third-party APIs, or other instances outside the issued ones. | |
| 14 | Static-asset checksums match | If the year's regulation validates static-file checksums, apply-skill leaves those files untouched. | |
| 15 | Concurrency under benchmarker ramp | Connection pools sized for peak concurrency; HTTP client to internal services uses a singleton with `MaxIdleConnsPerHost`. | |
| 16 | Disk does not fill during the run | Log rotation step in `DEPLOY.md`; `long_query_time` and access log set to high threshold for final benchmark. | |
| 17 | Spec violations are not caught only at "low load" | Per-endpoint verification includes both a single curl and a small concurrency burst (e.g. `ab -n 100 -c 10`). | |
| 18 | Benchmarker-visible secrets unchanged | Any seed admin password, fixed UUID, fixed token referenced by the benchmarker is not regenerated. | |

## How to fill the matrix

For each row, the apply-skill author writes one line of evidence:

> **Row 11**: GREEN. `ENDPOINTS.md §POST /api/posts` clears `postsByUser[uid]` after the INSERT in the same transaction. Verified by trace test in `DEPLOY.md` §3.

If the evidence is "we will check this later" → that row is RED, not YELLOW. The check belongs in the apply-skill itself.

## Common RED-row recoveries

| Symptom | Recovery |
|---------|----------|
| Row 4 RED — design references modifying frontend | Move the change to a server-side response; statics stay byte-identical. |
| Row 8 RED — apply-skill has no reboot test | Add the reboot test as the final step of `DEPLOY.md`. Non-negotiable. |
| Row 9/10 RED — cache fills lazily | Add a `warmCache(db)` call before `http.ListenAndServe`, and call it from the `/initialize` handler too. |
| Row 11 RED — write path skips cache invalidation | Either invalidate at write, or remove the cache and rely on a DB index. |
| Row 12 RED — DDL drops a column | Convert to additive: keep the old column, dual-write, deprecate later. For ISUCON the "later" never comes — keep both. |
| Row 15 RED — no pool sizing in design | Add `SetMaxOpenConns / SetMaxIdleConns / Transport.MaxIdleConnsPerHost` defaults to `TOPOLOGY.md`. |

## Final gate

Before phase 4 (emitting the apply-skill), every row must be GREEN or YELLOW *with an explicit mitigation noted*. Any RED row → return to phase 2.
