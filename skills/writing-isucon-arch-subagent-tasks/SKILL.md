---
name: writing-isucon-arch-subagent-tasks
description: Decomposes the apply-skill produced by designing-isucon-architecture into atomic tasks, materializes one Claude Code subagent per task, and emits a dispatcher slash command that fires the subagents in dependency order (parallel where the graph allows). Use when an applying-isucon-arch-<slug> skill exists and the team wants the architecture rollout to run as orchestrated subagent jobs rather than a single linear human-driven session, or when the user asks to "create subagents for this ISUCON design", "wire the ISUCON apply-skill into Claude Code agents", or "split the rollout into parallel agent tasks".
---

# Writing ISUCON Arch Rollout as Subagent Tasks

Turns an existing `applying-isucon-arch-<slug>/` skill (the artifact that
`designing-isucon-architecture` produces) into three runnable artifacts:

1. A **task graph** — atomic units of the architecture rollout, ordered by
   dependency.
2. A **Claude Code subagent** (`.claude/agents/...md`) per task — each one
   self-contained, scoped to a single phase / file set, ending in a
   verification step and one atomic commit.
3. A **dispatcher slash command** (`.claude/commands/isucon-arch-<slug>/dispatch.md`)
   plus an overview command — the dispatcher reads the graph, fires every
   ready (deps-satisfied) subagent in its **own git worktree** with the
   `Agent` tool's `isolation: "worktree"` option, fans out **up to 32 in
   parallel** (one per CPU core on the operator's 32-core box), merges each
   successful task's branch back to `main` between rounds, and stops on the
   first verification failure.

The point is to keep the human (or driver agent) at the orchestration level.
Each subagent gets a clean context window AND a clean filesystem branch with
only its slice of the design, so multi-instance topology + 5 endpoint
changes + deploy work do not collide in one giant transcript or one shared
working tree.

**Caveat**: worktree isolation covers the local git tree only. Remote state
(`ssh`-ed config edits on instances, MySQL DDL, nginx reloads, systemd
restarts) is shared across all worktrees. The DAG already serializes
remote-state-touching tasks (each is a single node), so this is not a
parallelism limit in the default decomposition — but if you split a
remote-touching task into siblings, encode their resource conflict via
`Depends on`, not by lowering the parallelism cap.

**Use this skill when**
- `.claude/skills/applying-isucon-arch-<slug>/` already exists (produced by
  `designing-isucon-architecture` phase 4),
- the team has more than one Claude session available (or wants to run later
  in the contest with the dispatcher firing background jobs),
- the design contains independent branches (topology + multiple endpoints +
  deploy) that benefit from parallel execution.

**Do NOT use this skill** before the apply-skill exists (run
`designing-isucon-architecture` first), for non-ISUCON task breakdown
(use `writing-implementation-tasks`), or when the team wants to drive every
change from one interactive session (just read the apply-skill directly).

## Workflow

### Phase 0 — Verify inputs (sequential, 2 min)

1. Confirm the input skill exists:
   `.claude/skills/applying-isucon-arch-<slug>/SKILL.md`,
   plus all six reference files (`TOPOLOGY.md`, `SCHEMA.md`, `CACHE.md`,
   `ENDPOINTS.md`, `DEPLOY.md`).
2. Confirm `docs/isucon-arch/DESIGN.md`, `BASELINE.md`, `CONSTRAINTS.md` are
   present — subagents will reference them.
3. Pick the slug. It MUST match the apply-skill's slug exactly. The output
   command directory will be `.claude/commands/isucon-arch-<slug>/`.

If any input is missing, stop and tell the user to finish
`designing-isucon-architecture` first.

### Phase 1 — Decompose the apply-skill into tasks (sequential, 10–20 min)

Walk the apply-skill's five phases (A–E) and produce one task per atomic
unit. The decomposition rules are in
[TASK-DECOMPOSITION.md](references/TASK-DECOMPOSITION.md). Summary:

- **Phase A → Topology**: one task per instance role (e.g. `topology-isu1`,
  `topology-isu2`, `topology-isu3-db`), one task for the nginx upstream
  block, one task for the env-var file. They mostly fan out in parallel.
- **Phase B → Schema**: one task per related DDL group. If `SCHEMA.md` lists
  five `CREATE INDEX` statements that can all land together, that is one
  task (not five) — schema is fast to apply and `EXPLAIN` checks come as a
  batch. Split only if the changes touch different tables and have
  independent verification.
- **Phase C → Cache**: split into `cache-warmup` (in-process map seed +
  `main` hook), `cache-invalidate-on-init` (`/initialize` handler addition),
  and `cache-shared-redis` (Redis client + key namespacing) when the design
  uses Redis. Skip subtasks the design does not require.
- **Phase D → Endpoints**: one task per top-5 endpoint, in alp-baseline rank
  order. Endpoint tasks are individually committable and individually
  verifiable. They MUST depend on the relevant schema or cache tasks.
- **Phase E → Deploy**: one task per concern: `deploy-systemd`,
  `deploy-nginx-static`, `deploy-log-rotation`, `deploy-reboot-test`. The
  reboot test is the **final** task in the graph.

Output the decomposition into a draft table (kept in working memory only):

| ID | Title | Depends on | Files | Verify |
|----|-------|-----------|-------|--------|
| topology-env | env.sh | – | /home/isucon/env.sh | source + echo $ISUCON_DB_HOST |
| schema-indexes | apply DDL | topology-env | webapp/sql/init.sql | EXPLAIN top-5 |
| ... | ... | ... | ... | ... |

Stay under ~12 tasks total. More than that and the dispatcher fan-out
becomes the bottleneck.

### Phase 2 — Build the dependency graph (sequential, 5 min)

Convert the depends-on column into an explicit DAG. Rules:

- A task may depend on multiple parents (a fan-in node).
- A task may have many children (a fan-out node).
- The graph MUST be acyclic. If two tasks reference each other, you have
  decomposed wrong — merge them.
- The reboot test (`deploy-reboot-test`) is a leaf with all deploy and
  endpoint tasks as parents.
- Phase A topology tasks have no parents.

Render the graph as an ASCII diagram in `overview.md` (template below). The
dispatcher does not parse the diagram — it parses the per-task `Depends on`
field. The diagram is for the human reader.

### Phase 3 — Emit subagent files (sequential, 15–25 min)

For each task in the table, write a subagent file at
`.claude/agents/isucon-arch-<slug>/<task-id>.md` following
[SUBAGENT-TEMPLATE.md](references/SUBAGENT-TEMPLATE.md).

Each subagent MUST:

- Have YAML frontmatter with `name`, `description`, `tools`, optional `model`.
- Embed the slice of the apply-skill it executes (do not say "see CACHE.md" —
  paste the relevant cache row, the warmup sketch, the invalidation list).
  The subagent runs in a fresh context; it cannot read what the dispatcher
  read.
- List the absolute file paths it will modify (the **Scope** section).
- End with a `Verify` block of executable commands.
- End with a `Commit` block invoking the `committing-code` skill, with a
  Conventional Commits message that includes `Task: isucon-arch-<slug>/<task-id>`.
- Refuse to run if its declared dependencies have not produced the expected
  artifacts (the **Pre-check** section).

A subagent is **not allowed** to edit files outside its declared scope. If
the dispatcher hands it a slice that requires touching another phase, that
is a decomposition bug — go back to phase 1 and re-split.

### Phase 4 — Emit the dispatcher and overview commands (sequential, 10 min)

Write two slash commands under `.claude/commands/isucon-arch-<slug>/`:

- `dispatch.md` — the orchestrator. Reads the task table, finds every task
  whose dependencies are marked done in `overview.md`, fires the
  corresponding subagent via the `Agent` tool with
  `isolation: "worktree"` (in parallel up to 32 at a time), waits for each
  to commit on its worktree branch, **merges every successful branch back
  to `main`** before re-evaluating the graph. Stops on the first verify
  failure or merge conflict. Template in
  [DISPATCH-COMMAND.md](references/DISPATCH-COMMAND.md).
- `overview.md` — the progress tracker. Static checklist of tasks; the
  source of truth for "is this task done" (after merge). Each subagent
  flips its own row to `- [x]` as part of its atomic commit; the dispatcher
  merges that flip into `main` along with the task changes. Template in
  [DISPATCH-COMMAND.md](references/DISPATCH-COMMAND.md).

### Phase 5 — Hand-off

Tell the user three things and stop:

1. The output paths:
   - subagents at `.claude/agents/isucon-arch-<slug>/`,
   - commands at `.claude/commands/isucon-arch-<slug>/`.
2. The recommended next step: run `/isucon-arch-<slug>/overview` to confirm
   the graph rendered correctly, then `/isucon-arch-<slug>/dispatch` to
   start the rollout.
3. The recovery hint: if any subagent's verify fails, the dispatcher stops.
   Read its commit, fix the underlying issue, re-run the dispatcher — it
   resumes from the first incomplete task.

Do **not** start running the dispatcher yourself from inside this skill.
Generation and execution are separate concerns; mixing them defeats the
clean-context property.

## Reference Files

- [TASK-DECOMPOSITION.md](references/TASK-DECOMPOSITION.md) — phase A–E
  decomposition rules, atom-size guide, when to split vs. merge.
- [SUBAGENT-TEMPLATE.md](references/SUBAGENT-TEMPLATE.md) — exact subagent
  file format with frontmatter, sections, and a worked example.
- [DISPATCH-COMMAND.md](references/DISPATCH-COMMAND.md) — dispatcher and
  overview command templates.
- [EXAMPLES.md](references/EXAMPLES.md) — worked end-to-end mappings for
  isuride (ISUCON14) and private-isu.

## Key Principles

1. **One subagent, one slice.** A subagent that touches three phases is a
   decomposition failure. Fix the split, do not let the subagent freelance.
2. **Subagents run cold and isolated.** They do not see the dispatcher's
   transcript or the apply-skill index, and they each run in their own
   git worktree (`isolation: "worktree"`). Embed every fact, file path,
   and verification command they need. "See the design doc" is a defect.
3. **The graph is the contract.** The dispatcher only fires what the graph
   permits. Adding a task means editing the graph (and the overview), not
   working around it.
4. **Verify is mandatory.** A subagent without an executable verify is a
   subagent that cannot be trusted. The dispatcher refuses to mark such a
   task done.
5. **Reboot is a node, not a footnote.** `deploy-reboot-test` is the final
   leaf and depends on every other deploy / endpoint task.
6. **Parallelism is bounded by the DAG, not by an arbitrary cap.** The
   dispatcher fans out up to 32 ready subagents at once (one per core on
   the operator's box). If two endpoint tasks touch overlapping files,
   mark a dependency between them — worktree isolation prevents the
   working-tree race, but the merge will conflict and halt the dispatcher.
   Encode the dependency.
7. **Remote state is global.** Worktrees do not isolate `ssh` edits, MySQL
   DDL, nginx reloads, or systemd restarts. The default decomposition puts
   each remote-touching task on its own DAG node, so this is not normally
   a concern; if you split such a task into siblings, encode the conflict
   in `Depends on`.

## Checklist (before declaring the rollout artifacts complete)

- [ ] Input apply-skill present and complete (six files).
- [ ] Task table covers every section of `SCHEMA.md`, `CACHE.md`,
      `ENDPOINTS.md`, `DEPLOY.md`, and the topology entries from
      `TOPOLOGY.md`.
- [ ] Dependency DAG is acyclic and has at least one source node and one
      sink node (the reboot test).
- [ ] Every subagent embeds its slice (no "see X.md" handwaving).
- [ ] Every subagent has a Pre-check, Scope, Steps, Verify, Update Overview,
      and Commit section.
- [ ] `overview.md` lists every task with a `- [ ]` checkbox and renders the
      DAG as ASCII.
- [ ] `dispatch.md` reads the same task list and respects the Depends on
      field exactly.
- [ ] Total task count is ≤ 12 (split further only if a single task exceeds
      the atom-size guide in `TASK-DECOMPOSITION.md`).
- [ ] Subagent and command directory names match the slug from the
      apply-skill: `isucon-arch-<slug>`.
