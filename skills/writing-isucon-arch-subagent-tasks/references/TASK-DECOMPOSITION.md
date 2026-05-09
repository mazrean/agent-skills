# Task Decomposition Rules

How to split the apply-skill (phases A–E) into atomic subagent tasks.

## Atom-size guide

A "task" is the unit a single subagent owns end-to-end. Right-size:

| Atom size | Indicator | Action |
|-----------|-----------|--------|
| Too small | < 5 lines of edits, no verify command of its own | Merge with the adjacent task |
| Right size | Single phase, 1–4 files, one runnable verify | Keep |
| Too large | Two phases, > 4 files, > 1 independent verify | Split along the verify boundary |

Hard cap: **≤ 12 tasks total** for one ISUCON problem. More than that and
the dispatcher's fan-out cost exceeds the parallelism win.

## Phase A — Topology

Source: `applying-isucon-arch-<slug>/references/TOPOLOGY.md`.

Default split:

| Task ID | Owns | Typical scope |
|---------|------|--------------|
| `topology-env` | env-var file | `/home/isucon/env.sh` |
| `topology-nginx` | nginx upstream + static block | `/etc/nginx/sites-available/isucon` |
| `topology-db-remote` | mysqld bind-address + GRANT | `/etc/mysql/mysql.conf.d/mysqld.cnf`, one-shot SQL |
| `topology-app-pool` | app-side conn-pool tuning | `webapp/go/main.go` (or equivalent) |

These four are independent of each other and depend on **nothing**. They
form the source nodes of the DAG.

Skip a task if the design does not change that surface. Example: if the
design keeps MySQL on `localhost`, drop `topology-db-remote`.

## Phase B — Schema

Source: `applying-isucon-arch-<slug>/references/SCHEMA.md`.

Default rule: **one task per migration file**. If `SCHEMA.md` lists five
indexes that all land in `webapp/sql/init.sql`, that is one
`schema-indexes` task — they share a verify (`EXPLAIN` of top-5 queries).

Split into multiple schema tasks only when:

- The DDL touches schemas that have independent rollback risk
  (e.g. `ALTER TABLE` on a hot table vs. a `CREATE TABLE` for a new
  cache-mirror table).
- Different tasks need different verifications (e.g. row-count check vs.
  EXPLAIN check).

Schema tasks depend on `topology-db-remote` if and only if the design moved
the DB to a separate instance. Otherwise no parents.

## Phase C — Cache

Source: `applying-isucon-arch-<slug>/references/CACHE.md`.

Default split:

| Task ID | Owns | Depends on |
|---------|------|-----------|
| `cache-warmup` | in-process maps + `main` warmup hook | `schema-indexes` (warmup queries use indexes) |
| `cache-init-reset` | `/initialize` handler additions | `cache-warmup` |
| `cache-redis` | Redis client + key namespace | `topology-env` (`REDIS_URL`) |

Drop tasks the design does not require. If the design uses only
in-process caches, drop `cache-redis`. If `/initialize` already correctly
clears per-process state, drop `cache-init-reset`.

## Phase D — Endpoints

Source: `applying-isucon-arch-<slug>/references/ENDPOINTS.md`.

**One task per endpoint**, in alp-baseline rank order. Task IDs use the
pattern `endpoint-<rank>-<short>`, e.g. `endpoint-1-app-notification`.

Each endpoint task's `Depends on` is the union of:

- the schema task that adds its index (if any),
- the cache task that holds its cache (if any),
- and any earlier endpoint task that edits the same file.

Two endpoint tasks editing the same handler file MUST chain — do not
parallelize them. The dispatcher will not detect overlapping edits, so
encode the dependency explicitly.

Stop at the top 5 endpoints. Lower-ranked endpoints are not worth a
dedicated subagent — their delta is below the noise floor of one benchmark
run.

## Phase E — Deploy

Source: `applying-isucon-arch-<slug>/references/DEPLOY.md`.

Default split:

| Task ID | Owns | Depends on |
|---------|------|-----------|
| `deploy-systemd` | systemd unit + enable/start | `topology-env` |
| `deploy-script` | `/home/isucon/deploy.sh` | `deploy-systemd` |
| `deploy-log-rotation` | log-truncate + verbose-log-off recipe | `deploy-script` |
| `deploy-reboot-test` | reboot each instance + score check | every other task |

`deploy-reboot-test` is the **only** task that depends on every other
task. It is the unique sink of the DAG.

## Decomposition heuristics

When in doubt:

1. **Does this task have its own verify?** If yes, it is its own task. If
   no, fold it into the next task that has one.
2. **Can two tasks land in any order without breaking each other?** If
   yes, they are siblings (parallel). If no, encode the dependency.
3. **Would a benchmarker run between these tasks be informative?** If yes,
   they are separate tasks (so the dispatcher can stop and observe). If
   no, they belong together.
4. **Does the task touch a file another task also touches?** If yes,
   serialize them with an explicit dependency. Never rely on the
   dispatcher to merge edits.

## Anti-patterns

- **A "do everything for endpoint X" task that adds an index, writes a
  cache, AND rewrites the handler.** Three different verifies, three
  different rollback granularities. Split into schema → cache → endpoint.
- **A "topology" task that also runs the migration.** Topology is "where
  does the process run", not "what is in the database". Split.
- **A schema task with no `EXPLAIN` verify.** If the design says the
  index changes a query plan, the task must prove it.
- **An endpoint task that depends on the reboot test.** The reboot test is
  the sink — nothing depends on it.
- **Merging the reboot test into `deploy-log-rotation`.** They have
  different verifies. Reboot test is its own node.
