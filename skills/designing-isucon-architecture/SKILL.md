---
name: designing-isucon-architecture
description: Analyzes an existing ISUCON-style application, designs an optimal infrastructure and architecture redesign that respects every ISUCON rule, and emits the proposal as a self-contained Agent Skill that another Claude session can read and execute. Use when starting an ISUCON contest or practice, drafting a contest-day architecture plan before touching code, or when the user asks to "design the architecture", "plan the topology", or "produce an implementation skill" for an ISUCON problem.
---

# Designing ISUCON Architecture

Produces an architecture-first redesign plan for an ISUCON-style application. The output is **not a code change** — it is an **Agent Skill** that captures:

- the validated regulation constraints,
- the chosen instance topology,
- the storage and schema layout,
- the cache and consistency design,
- the per-hot-endpoint algorithmic notes,
- the deploy / systemd / nginx changes,
- and the verification commands to run after each phase.

A second Claude session (or the same session in a later step) reads the produced skill and applies it. Separating *design* from *execution* keeps the design reviewable and the execution mechanical.

**Use this skill when**
- starting an ISUCON contest or practice (`private-isu`, `isucon14`, past-year repos),
- the team agrees on a "design first, code second" workflow,
- the user asks to plan, propose, or document an architecture for an ISUCON problem,
- the user wants the plan as a runnable skill rather than a one-shot markdown doc.

**Do NOT use this skill** for raw tuning loops with no plan (use `winning-isucon`), for porting between languages (use `porting-isucon-rust-to-go`), or for general non-ISUCON backend redesign.

## Why design before code

A team that jumps straight to "add this index" without a topology decision spends the back half of the contest fighting a topology that no longer fits the new bottleneck. A 30-minute architecture pass costs nothing relative to the 8-hour clock, and pays back when the third hour's optimization is already decided in hour zero.

This skill makes the design pass explicit, validates it against the regulation, and persists it as a runnable artifact so the executing session does not re-derive it.

## Workflow

### Phase 0 — Bound the problem (sequential, 5–15 min)

1. **Read the year's regulation and manual.** Score formula, request timeout, banned actions, asset-checksum rules, reboot-test specifics.
2. **Inventory the immutable items.** API URI/method, response shape, frontend statics, `isuwari`, `isuadmin`. Record absolute file paths.
3. **Inventory the mutable surface.** Reference languages, framework, DB version, presence of MySQL/Postgres/Redis, nginx version, instance count and specs (`nproc`, `free -h`, `df -h`).
4. **Locate `/initialize`.** Note its time budget (usually ≤30s) — the design must initialize within it.
5. **Decide the language target.** If the team chose a non-default language, schedule the porting work via `porting-isucon-rust-to-go` (or its language equivalent) — this skill assumes the language target is already chosen.

Output: `docs/isucon-arch/CONSTRAINTS.md` summarizing what may and may not change.

See [DISCOVERY-CHECKLIST.md](references/DISCOVERY-CHECKLIST.md) for the exact items to record.

### Phase 1 — Measure the baseline (sequential, 20–40 min)

Architecture decisions without numbers are guesses. Before designing, run one full benchmark and capture:

1. **`alp`** on the nginx access log → endpoint × {count, sum, p99}.
2. **`pt-query-digest`** on the slow query log (with `long_query_time = 0`) → query × {count, sum}.
3. **`pprof`** CPU profile of the app for the run's duration.
4. **Per-instance Netdata snapshot** at peak load → CPU per core, disk `iowait`, network out, MySQL QPS.

Reuse the procedure from `winning-isucon/MEASUREMENT.md` — do not duplicate it here.

Record the baseline score, the top-5 alp rows, the top-5 query-digest rows, and the dominant pprof leaves into `docs/isucon-arch/BASELINE.md`.

### Phase 2 — Design across five dimensions (sequential, 30–60 min)

For each dimension, pick a target state and write a one-paragraph justification **tied to a specific baseline number**. If no baseline number motivates a change in a given dimension, leave that dimension unchanged.

The five dimensions are detailed in [DESIGN-DIMENSIONS.md](references/DESIGN-DIMENSIONS.md):

1. **Topology** — which process runs on which instance. Options: all-on-one, app+DB split, multi-app behind nginx, app+DB+cache split. Decide based on which subsystem saturates first.
2. **Storage** — MySQL as-is, MySQL with schema/index changes, MySQL + Redis sidecar, MySQL replaced by SQLite (read-mostly), or in-memory with append-only WAL. Decide based on read/write ratio and durability needs.
3. **Cache and consistency** — in-process immutable, in-process mutable with `sync.RWMutex`, shared via Redis/Memcached, or sticky-routing by user ID. Decide based on whether multi-app is in the topology.
4. **Algorithmic / endpoint redesign** — for each alp top-5 endpoint, classify the win as index, N+1, bulk write, in-memory pre-computation, or domain-specific algorithm. Cross-reference `winning-isucon/OPTIMIZATION-PATTERNS.md`.
5. **Deploy and reboot survival** — systemd unit changes, env-var deltas for DSN, cache-warmup hook, `/initialize` idempotency.

Output: `docs/isucon-arch/DESIGN.md` — one section per dimension, plus a small ASCII topology diagram.

### Phase 3 — Validate against ISUCON rules (sequential, 10 min)

Cross-check the design against the matrix in [CONSTRAINT-MATRIX.md](references/CONSTRAINT-MATRIX.md). Each row is a rule; mark the design's status (GREEN / YELLOW / RED).

Common failure modes:

- Cache write path that breaks read-after-write semantics → spec violation.
- In-memory state without a warmup hook → reboot test failure.
- Schema change that drops a column the benchmarker still reads.
- Async write whose eventual-consistency window exceeds what the benchmarker tolerates.
- Static-asset modification that changes a checksum the benchmarker validates.

Any RED row → revise the design. Do **not** proceed with a known-failing rule.

### Phase 4 — Emit the implementation as an Agent Skill (sequential, 15 min)

Write the result to `.claude/skills/applying-isucon-arch-<problem-slug>/` following [OUTPUT-SKILL-TEMPLATE.md](references/OUTPUT-SKILL-TEMPLATE.md).

The produced skill MUST contain:

- `SKILL.md` — overview, ordered apply-phases, verification per phase, rollback notes, links back to `DESIGN.md` / `CONSTRAINTS.md`.
- `references/TOPOLOGY.md` — exact instance roles, env vars, listen addresses, nginx upstream snippet.
- `references/SCHEMA.md` — DDL deltas (CREATE INDEX, ALTER TABLE, new tables) with `EXPLAIN` expectations.
- `references/CACHE.md` — cache keys, TTL, invalidation paths, warmup procedure.
- `references/ENDPOINTS.md` — per hot-endpoint plan (current shape → new shape, code sketch, verification).
- `references/DEPLOY.md` — systemd edits, deploy script, log rotation, reboot-test recipe.

**Naming**: `applying-isucon-arch-<problem-slug>`, where `<problem-slug>` is the ISUCON problem repo name (e.g. `isuride`, `isupipe`, `private-isu`). Lowercase, hyphens only, ≤64 chars.

The produced skill must be **self-contained** — embed the relevant codebase excerpts; do not require the executing session to re-analyze the source.

### Phase 5 — Hand-off

Tell the user three things and stop:

1. The skill path: `.claude/skills/applying-isucon-arch-<slug>/`.
2. The recommended next step: invoke the apply-skill and run its phase 1.
3. The rollback hint: commit before invoking; revert if it regresses.

Do **not** start applying changes yourself from inside this skill — execution is the produced skill's job.

## Reference Files

- [DISCOVERY-CHECKLIST.md](references/DISCOVERY-CHECKLIST.md) — phase 0 inventory items.
- [DESIGN-DIMENSIONS.md](references/DESIGN-DIMENSIONS.md) — the five axes, their options, decision rules.
- [CONSTRAINT-MATRIX.md](references/CONSTRAINT-MATRIX.md) — phase 3 rule-by-rule validation matrix.
- [OUTPUT-SKILL-TEMPLATE.md](references/OUTPUT-SKILL-TEMPLATE.md) — exact format the produced apply-skill must follow.
- [EXAMPLE-DESIGNS.md](references/EXAMPLE-DESIGNS.md) — worked examples (ISUCON14, ISUCON13, private-isu).

## Key Principles

1. **Design once, execute once.** If the apply-skill needs revisions, edit `DESIGN.md` first, regenerate the apply-skill, then run.
2. **Every change has a number.** Each dimension's decision points at a row in `BASELINE.md`. Decisions without numbers get reverted under pressure.
3. **The constraint matrix is non-negotiable.** A design that violates a rule scores 0 on the run that catches it — assume the benchmarker catches it.
4. **The produced skill is the contract.** Anything missing from the produced skill will not be executed correctly. Embed, do not handwave.
5. **Reboot is a phase, not a postscript.** `DEPLOY.md` ends with a reboot test as the last verification. No "we will add this later".
6. **One problem, one apply-skill.** Do not bundle multiple ISUCON problems — slugs collide and the skill becomes unwieldy.

## Checklist (before declaring the design complete)

- [ ] `CONSTRAINTS.md` lists every immutable item with absolute paths.
- [ ] `BASELINE.md` has alp top-5, query-digest top-5, pprof top-5, per-instance peak metrics.
- [ ] `DESIGN.md` covers all five dimensions, each justified by a baseline number.
- [ ] Constraint matrix shows zero RED rows.
- [ ] Apply-skill is self-contained — no step reads "see codebase" without a path.
- [ ] Apply-skill includes a reboot test as the last step of `DEPLOY.md`.
- [ ] Apply-skill name matches `^applying-isucon-arch-[a-z0-9-]+$` and is ≤64 chars.
