# Worked Examples

End-to-end mappings from a real apply-skill (`applying-isucon-arch-<slug>/`)
to the subagent + dispatcher artifacts. Read alongside
`TASK-DECOMPOSITION.md` and `SUBAGENT-TEMPLATE.md`.

## Example 1 — isuride (ISUCON14)

### Apply-skill summary

- **Topology**: nginx + app on isu1, app on isu2, mysql + redis on isu3.
- **Schema**: 4 indexes added to `webapp/sql/init.sql`.
- **Cache**: in-process `chairsByID` (immutable seed), Redis-backed
  `rideStateByID`, `/initialize` clears both.
- **Endpoints**: top-3 = `GET /api/app/notification`,
  `POST /api/chair/coordinate`, `GET /api/owner/sales`.
- **Deploy**: `isuride-go.service`, `deploy.sh`, log-truncation, reboot
  test.

### Task table (12 tasks)

| ID | Depends on |
|----|-----------|
| topology-env | – |
| topology-nginx | – |
| topology-db-remote | – |
| topology-app-pool | – |
| schema-indexes | topology-db-remote |
| cache-warmup | schema-indexes |
| cache-redis | topology-env |
| endpoint-1-app-notification | schema-indexes, cache-warmup |
| endpoint-2-chair-coordinate | schema-indexes, cache-redis |
| endpoint-3-owner-sales | schema-indexes |
| deploy-systemd | topology-env |
| deploy-reboot-test | every other task |

(`deploy-script` and `deploy-log-rotation` are folded into the
`deploy-systemd` and `deploy-reboot-test` tasks for this problem because
the apply-skill has only a four-line `deploy.sh` and a two-line
log-truncation step — too small to warrant their own subagent. This is
the merge rule from `TASK-DECOMPOSITION.md`.)

### DAG

```
topology-env ──┬─► cache-redis ────┐
               │                    │
               ├─► deploy-systemd   │
               │                    │
topology-nginx │                    │
               │                    │
topology-db-remote ──► schema-indexes ──┬─► cache-warmup ──┐
                                         │                  │
                                         ├─► endpoint-1 ◄───┘
                                         │
                                         ├─► endpoint-2 ◄── cache-redis
                                         │
                                         └─► endpoint-3
                                                          │
topology-app-pool ────────────────────────────────────────┤
                                                          ▼
                                                   deploy-reboot-test
```

The four `topology-*` tasks fan out from the source. Schema is the choke
point — five tasks depend on it. The reboot test fans in.

### Round-by-round dispatcher trace (32 parallelism, worktree isolation)

Each "Fired" entry is one `Agent` tool call with
`isolation: "worktree"`. Each fired subagent gets its own worktree off
`main`; the dispatcher merges every successful branch back to `main`
between rounds. Cap is 32 — none of these rounds approach it; the DAG
is the binding constraint.

| Round | Fired (in parallel) | Merged to main | Bound by |
|-------|--------------------|--------------- |----------|
| 1 | topology-env, topology-nginx, topology-db-remote, topology-app-pool | all four | DAG (4 source nodes) |
| 2 | schema-indexes, cache-redis, deploy-systemd | all three | schema/cache/deploy fan-out |
| 3 | cache-warmup, endpoint-2-chair-coordinate, endpoint-3-owner-sales | all three | schema-indexes fan-out |
| 4 | endpoint-1-app-notification | one | needs cache-warmup from round 3 |
| 5 | deploy-reboot-test | one | sink node, depends on all |

Five rounds, 12 tasks. Wall time ≈ max(parallel branch latencies) per
round, dominated by:

- Round 2: schema DDL (mysql round-trip + EXPLAIN verify) — typically
  the slowest schema verify.
- Round 3: endpoint rewrite + go build + curl diff — typically 30–60s.
- Round 5: reboot of three instances + benchmark — multiple minutes,
  deliberately serial.

Worktrees do not change the DAG. Worktrees change only "could two
sibling tasks edit the same file without locking each other out" —
yes, they can, because each is in its own checkout. The dispatcher's
merge step folds the branches back together; the DAG guarantees the
merges are non-conflicting.

If parallelism > 32 ever became useful (e.g. 30 endpoint tasks in one
round on a bigger box), raise the cap — the dispatcher logic is
unchanged. On the current 32-core operator box, no realistic ISUCON
decomposition produces a round that fires 32 tasks; the cap is a
ceiling, not a target.

### Subagent file: `endpoint-1-app-notification`

(See the worked example in `SUBAGENT-TEMPLATE.md` — same task, full
template.)

### Common verify per task

| Task | Verify (one-liner) |
|------|-------------------|
| topology-env | `ssh isu1 'source /home/isucon/env.sh && echo $ISUCON_DB_HOST'` returns isu3 IP |
| topology-nginx | `ssh isu1 'sudo nginx -t && sudo systemctl reload nginx'` exits 0 |
| topology-db-remote | `mysql -h <isu3-ip> -uisucon -pisucon -e 'SELECT 1'` from isu1 |
| topology-app-pool | `grep -E "SetMaxOpenConns|SetMaxIdleConns" webapp/go/main.go` matches |
| schema-indexes | `mysql -e "SHOW INDEX FROM rides" isuride` shows `idx_rides_user_created` |
| cache-warmup | `curl http://isu1:8080/health` after fresh start; log shows "warm complete" |
| cache-redis | `redis-cli -h <isu3-ip> ping` returns PONG; key `ride_state:*` populated after one ride |
| endpoint-* | `diff <(jq -S . baseline.json) <(jq -S . after.json)` empty + alp shows lower sum |
| deploy-systemd | `ssh isuN 'systemctl is-active isuride-go.service'` returns `active` for N∈{1,2} |
| deploy-reboot-test | `ssh isuN 'sudo reboot'` then `systemctl is-active` for all three services on each |

## Example 2 — private-isu (single-instance)

### Apply-skill summary

- **Topology**: unchanged — single instance. No `topology-db-remote`,
  no nginx upstream split.
- **Schema**: 2 indexes (`comments(post_id, created_at)`,
  `posts(user_id, created_at)`) + delete a redundant column.
- **Cache**: in-process user-by-id map only. No Redis.
- **Endpoints**: top-3 = `GET /`, `GET /image/:id`, `POST /`.
- **Deploy**: systemd unit edit + log-rotation only. No reboot script
  changes (default systemd start order is fine).

### Task table (7 tasks)

| ID | Depends on |
|----|-----------|
| topology-app-pool | – |
| schema-indexes | – |
| cache-warmup | schema-indexes |
| endpoint-1-index | schema-indexes, cache-warmup |
| endpoint-2-image | – |
| endpoint-3-post | schema-indexes |
| deploy-reboot-test | every other task |

Note: `endpoint-2-image` is a pure nginx static-file move. It does not
depend on schema or cache. It runs in parallel with everything else.

### DAG

```
topology-app-pool ─────────────────────────────────┐
                                                    │
schema-indexes ──┬─► cache-warmup ──┬─► endpoint-1  │
                 │                   │              │
                 ├─► endpoint-3      │              │
                 │                                  │
endpoint-2 ─────────────────────────────────────────┤
                                                    ▼
                                            deploy-reboot-test
```

### Why no `topology-env`, `topology-nginx`, `topology-db-remote`?

The apply-skill does not change those. The decomposition skill MUST drop
tasks the apply-skill does not require. A subagent that does not modify
anything is a defect — its commit would be empty.

### Why no `cache-init-reset`?

`/initialize` already clears in-process state via app restart in the
private-isu reference; the cache subagent only adds the warmup hook.
`cache-init-reset` would be a no-op task and is dropped per
`TASK-DECOMPOSITION.md` rule "skip subtasks the design does not require".

## Decomposition mistakes seen in practice

### Mistake 1: bundling topology + schema

```
topology-and-schema  (one task, edits 5 files across 3 phases)
```

The verify is incoherent ("did the indexes land or did the env file
ship?"). Split as the table above shows.

### Mistake 2: serializing all endpoint tasks

```
endpoint-1 → endpoint-2 → endpoint-3 (chain)
```

Endpoints touching different files have no real dependency — chaining
forfeits parallelism for no safety win. Only chain endpoints that edit
the same file (or share a fragile state).

### Mistake 3: making `deploy-reboot-test` non-final

```
deploy-systemd → deploy-reboot-test → deploy-log-rotation
```

The reboot test is the rollout's acceptance gate. Anything after it
risks invalidating the score. Move log-rotation in front:

```
deploy-systemd → deploy-log-rotation → deploy-reboot-test
```

### Mistake 4: subagent that reads the apply-skill

```markdown
## Steps
1. Read .claude/skills/applying-isucon-arch-isuride/references/ENDPOINTS.md.
2. Apply section #1.
```

The subagent runs cold — it cannot reliably read another file's content
into instructions. Embed the slice directly under `## Embedded slice`
per `SUBAGENT-TEMPLATE.md` §5.
