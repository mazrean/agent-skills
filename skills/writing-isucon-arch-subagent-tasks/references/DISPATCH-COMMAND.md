# Dispatcher and Overview Command Templates

Two slash commands at `.claude/commands/isucon-arch-<slug>/`:

- `dispatch.md` — orchestrator. Walks the graph, fires ready subagents in
  parallel, halts on verify failure.
- `overview.md` — read-only progress tracker. Source of truth for "which
  tasks are done".

## overview.md

```markdown
---
description: Show progress and next ready tasks for the isucon-arch-<slug> rollout.
allowed-tools: Bash, Read
---

# isucon-arch-<slug> — Rollout Overview

<background_information>
- **Apply skill**: .claude/skills/applying-isucon-arch-<slug>/SKILL.md
- **Design**: docs/isucon-arch/DESIGN.md
- **Mission**: report which subagent tasks are done and which are ready to fire.
</background_information>

<instructions>
## Execution Steps

1. Read the **Tasks** checklist below — `- [x]` entries are the source of
   truth for completed tasks (each subagent flips its own row at commit
   time).
2. For each `- [ ]` task, cross-check that its commit really is missing:
   `git log --grep="Task: isucon-arch-<slug>/<task-id>" --oneline` is
   empty.
3. If a checklist entry disagrees with git state, report the drift
   explicitly and recommend reconciling before dispatching anything.
4. Compute **ready tasks** = unchecked tasks whose every parent (per the
   **Dependency DAG**) is already `- [x]`.
5. Report: completed count, in-progress count (none expected — subagents
   commit atomically), ready set, blocked set. Recommend
   `/isucon-arch-<slug>/dispatch` if the ready set is non-empty.

## Tasks

- [ ] topology-env: env.sh on every instance
- [ ] topology-nginx: nginx upstream + static block
- [ ] topology-db-remote: mysqld bind-address + GRANT
- [ ] topology-app-pool: app-side connection-pool tuning
- [ ] schema-indexes: DDL deltas in webapp/sql/init.sql
- [ ] cache-warmup: in-process cache + main warmup hook
- [ ] cache-init-reset: /initialize handler additions
- [ ] cache-redis: Redis client + key namespace
- [ ] endpoint-1-<short>: top-1 endpoint redesign
- [ ] endpoint-2-<short>: top-2 endpoint redesign
- [ ] endpoint-3-<short>: top-3 endpoint redesign
- [ ] deploy-systemd: systemd unit + enable/start
- [ ] deploy-script: deploy.sh
- [ ] deploy-log-rotation: log truncation + verbose-log-off
- [ ] deploy-reboot-test: reboot every instance, score within 5%

> Each task line is flipped to `- [x]` by its own subagent's atomic
> commit. Do not edit this checklist manually from the overview command.

## Dependency DAG

```
topology-env ──┬─► schema-indexes ──┬─► cache-warmup ──► cache-init-reset
               │                    │                        │
topology-nginx │                    └────────────────────┐   │
               │                                          ▼   ▼
topology-db-remote ────────────────────────────────► endpoint-1-<short>
                                                          │
topology-app-pool                                         ▼
                                                      endpoint-2-<short>
cache-redis ◄── topology-env                              │
                                                          ▼
                                                      endpoint-3-<short>
                                                          │
                                                          ▼
deploy-systemd ──► deploy-script ──► deploy-log-rotation ─┤
                                                          ▼
                                                  deploy-reboot-test
```

(Replace with the real DAG produced by the writing skill — this is a
schematic.)
</instructions>

## Output Description

Print a four-line summary:
- Done: N / total
- Ready now: <list>
- Blocked: <list with which parent is missing>
- Suggested next: `/isucon-arch-<slug>/dispatch`
```

## dispatch.md

```markdown
---
description: Orchestrate the isucon-arch-<slug> rollout. Fires every ready subagent in its own git worktree (up to 32 in parallel), merges each successful branch back to main, and halts on the first verify failure or merge conflict.
allowed-tools: Bash, Read, Agent
---

# isucon-arch-<slug> — Dispatcher

<background_information>
- **Source of truth for "done"**: git log trailers
  `Task: isucon-arch-<slug>/<task-id>` on `main` after merge.
- **Source of truth for "task list"**: the **Tasks** section of
  `.claude/commands/isucon-arch-<slug>/overview.md`.
- **Dependency rules**: the **Dependency DAG** in `overview.md`,
  re-encoded as the table below for unambiguous parsing.
- **Isolation**: each subagent runs in a fresh git worktree via
  `isolation: "worktree"`. Its commit lands on a per-worktree branch; the
  dispatcher merges that branch into `main` between rounds.
- **Concurrency**: up to **32 subagents in parallel** per round (operator
  box has 32 CPU cores). Bounded by the ready set size and the DAG, not
  by an arbitrary global cap below 32.
- **Mission**: fire every subagent whose dependencies are satisfied,
  in parallel; merge their branches; halt on the first failure or
  conflict; resume cleanly on re-invoke.
</background_information>

<instructions>

## Task table (parsed by this command)

| Task ID | Subagent name | Depends on |
|---------|---------------|-----------|
| topology-env | isucon-arch-<slug>-topology-env | – |
| topology-nginx | isucon-arch-<slug>-topology-nginx | – |
| topology-db-remote | isucon-arch-<slug>-topology-db-remote | – |
| topology-app-pool | isucon-arch-<slug>-topology-app-pool | – |
| schema-indexes | isucon-arch-<slug>-schema-indexes | topology-db-remote |
| cache-warmup | isucon-arch-<slug>-cache-warmup | schema-indexes |
| cache-init-reset | isucon-arch-<slug>-cache-init-reset | cache-warmup |
| cache-redis | isucon-arch-<slug>-cache-redis | topology-env |
| endpoint-1-<short> | isucon-arch-<slug>-endpoint-1-<short> | schema-indexes, cache-warmup |
| endpoint-2-<short> | isucon-arch-<slug>-endpoint-2-<short> | schema-indexes |
| endpoint-3-<short> | isucon-arch-<slug>-endpoint-3-<short> | cache-redis |
| deploy-systemd | isucon-arch-<slug>-deploy-systemd | topology-env |
| deploy-script | isucon-arch-<slug>-deploy-script | deploy-systemd |
| deploy-log-rotation | isucon-arch-<slug>-deploy-log-rotation | deploy-script |
| deploy-reboot-test | isucon-arch-<slug>-deploy-reboot-test | <every other task> |

(The writing skill replaces this table with the real one.)

## Execution Steps

1. **Snapshot state.** Confirm `main` is the current branch, working tree
   clean. For every task ID in the table, run:
   `git log main --grep="Task: isucon-arch-<slug>/<task-id>" --oneline | head -1`.
   A non-empty line means the task is `done`. Empty means `pending`.
2. **Cross-check overview.** Read `overview.md` and confirm every `done`
   task is `- [x]` and every `pending` task is `- [ ]`. If a row
   disagrees, halt and report the drift — do not fire any subagent.
3. **Compute ready set.** A task is `ready` if it is `pending` AND every
   dependency in its `Depends on` column is `done`.
4. **If ready set is empty AND there are pending tasks**: report which
   parent is blocking each pending task and stop. (Indicates a previous
   failure that has not been resolved.)
5. **If ready set is empty AND all tasks are done**: report
   "Rollout complete. Final score check pending — re-run benchmarker."
   and stop.
6. **Cap to 32.** Take the first 32 of the ready set (insertion order
   from the task table). The remainder waits for the next round. The
   cap matches the operator's CPU core count; raise only if both the
   box and the DAG can absorb more.
7. **Fire ready tasks in parallel.** Send a single message containing
   one `Agent` tool call per chosen task, with:
   - `subagent_type`: the task's subagent name (e.g.
     `isucon-arch-<slug>-endpoint-1-<short>`).
   - `description`: the task's short title.
   - `prompt`: "Run task <task-id> for isucon-arch-<slug>. Follow the
     subagent's instructions verbatim. Do not invoke other tasks. The
     working tree you see is a fresh worktree off `main`; commit on the
     worktree's current branch."
   - **`isolation: "worktree"`** — required. Each subagent gets its own
     worktree off `main`.
   The Agent tool runs each subagent in a fresh context AND a fresh
   working tree, then returns the worktree path and branch name.
8. **Wait for all firings to return.** Each subagent commits atomically
   on its worktree's branch. The `Task:` trailer is on that branch's
   tip commit, not yet on `main`.
9. **Merge successful branches into `main`.** For each subagent that
   returned a non-empty branch (changes were committed):
   ```bash
   git merge --no-ff --no-edit <branch>
   ```
   Process branches in DAG-topological order (parents before children
   are guaranteed by the round structure; among siblings of one round,
   any order works). On merge conflict, halt — do not attempt
   automatic resolution. Report the conflicting files and the two
   branches involved.
10. **Detect failures.** For every task that was fired but did NOT
    return a branch with a `Task: isucon-arch-<slug>/<task-id>` trailer
    on its tip commit, report it as failed and halt the dispatcher.
    Do not fire dependents of a failed task. Do not merge a failed
    task's worktree (it should have been auto-cleaned because the
    subagent made no commits, but verify).
11. **Re-snapshot** (step 1).
12. **Loop.** Re-evaluate ready set (step 3). Re-fire (step 7). Continue
    until ready set is empty.

## Halt-and-resume semantics

- Halting on failure is the default. The user reads the failed
  subagent's transcript, fixes the underlying issue (or edits the
  apply-skill and re-runs `writing-isucon-arch-subagent-tasks`), then
  re-invokes `/isucon-arch-<slug>/dispatch`.
- The dispatcher is idempotent: a task whose commit already exists on
  `main` is treated as done and not re-fired. The merge step is
  idempotent for the same reason — re-running fast-forwards or skips.
- The dispatcher never edits the overview checklist — only subagents do.
  Drift between checklist and git state is a halt condition, not a
  silent recovery.
- On merge conflict: the user resolves on `main` manually, commits with
  the same `Task:` trailer, deletes the worktree branch, then re-runs
  the dispatcher. The dispatcher will see the trailer on `main` and
  treat the task as done.

## Parallelism guardrails

- Fan-out cap: **32**. Matches the operator's 32-core box. Raise only
  after measuring that round-N latency is dominated by the slowest
  subagent and not by CPU/IO saturation.
- The DAG is the real limit. If only 3 tasks are ready in a round, only
  3 fire — the cap is a ceiling, not a target.
- Worktree isolation handles file-edit contention. The dispatcher does
  NOT need additional file locks.
- **Remote state is NOT isolated.** SSH edits to instance configs,
  MySQL DDL, nginx reloads, and systemd restarts are global. The default
  decomposition gives each such operation its own DAG node — if you
  override that, encode the conflict via `Depends on`, not via a global
  parallelism cap below 32.
- Endpoint tasks editing the same file are serialized by their `Depends
  on` column. The dispatcher does not re-check at fire time; it trusts
  the graph.

</instructions>

## Output Description

After each round, print:

- Round N fired: <list of task IDs, with parallelism count up to 32>
- Just-merged: <list of task IDs whose branches landed on main>
- Now ready: <list of task IDs to be fired next round>
- Failed: <list, if any, with the failing verify message>
- Conflicts: <list, if any, with the conflicting files and branches>
- Total progress: N / total
- Final hint: when complete, run the benchmarker and check score within
  5% of the last good run.
```

## Notes for the writing skill

- Replace `<slug>` everywhere before writing the file.
- Replace the example task table with the real decomposition from phase 1
  of the parent skill workflow.
- Replace the schematic DAG in `overview.md` with the actual ASCII DAG.
- The writing skill does NOT need to fill in the `<short>` substring for
  endpoint task IDs unless the apply-skill does — keep the ID stable
  across both files (overview, dispatch, subagent name).
