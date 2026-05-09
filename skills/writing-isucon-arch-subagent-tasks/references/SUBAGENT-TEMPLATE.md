# Subagent File Template

The exact format for each `.claude/agents/isucon-arch-<slug>/<task-id>.md`
file. Each subagent runs in a fresh context AND a fresh git worktree —
embed every fact it needs.

## Runtime contract (set by the dispatcher)

- The dispatcher fires this subagent with the `Agent` tool's
  `isolation: "worktree"` option. The subagent's working directory is a
  temporary worktree branched off `main`.
- All ancestor tasks are already merged into `main` at fire time, so the
  subagent's worktree contains every parent's changes. Pre-check commands
  that grep `git log` see those parents' commits via the worktree's
  inherited history.
- The subagent commits to its worktree's current branch (NOT to `main`).
  The dispatcher merges that branch back to `main` after the subagent
  returns. Do not push, do not switch branches, do not interact with
  `main` directly.
- Up to 32 sibling subagents may be running concurrently in their own
  worktrees. Local file edits cannot collide. Remote-state edits
  (`ssh`, `mysql -e DDL`, `systemctl reload nginx`) DO collide — by
  design, the DAG ensures only one such task runs per round, but be
  aware that your `Verify` block runs against shared remote state.

## File location

```
.claude/agents/isucon-arch-<slug>/<task-id>.md
```

`<task-id>` matches the ID from the decomposition table (e.g.
`endpoint-1-app-notification`, `topology-env`).

## Frontmatter

```yaml
---
name: isucon-arch-<slug>-<task-id>
description: <one sentence: what this subagent does, when the dispatcher should fire it>. Do NOT invoke directly — fire only via /isucon-arch-<slug>/dispatch.
tools: Bash, Read, Write, Edit, Grep, Glob, Skill
model: sonnet
---
```

Notes:

- `name` is globally unique per project. The `isucon-arch-<slug>-` prefix
  prevents collisions between problems.
- `tools` MUST include `Skill` (for invoking `committing-code`) and `Bash`
  (for verify commands). `Edit` and `Write` are required for all but
  reboot-test-style read-only tasks.
- `model: sonnet` is the default. Use `opus` only for endpoint tasks whose
  algorithmic redesign is non-trivial (rare). `haiku` is too small for
  ISUCON work — do not pick it.
- The description's "Do NOT invoke directly" line is load-bearing: it
  prevents the auto-invocation heuristic from firing the subagent on a
  user message that happens to mention the task topic.

## Required body sections

Every subagent body has exactly these eight sections, in this order. Do
not omit. Do not reorder.

### 1. `# <Task title>`

A one-line H1. Example: `# Endpoint #1 — GET /api/app/notification`.

### 2. `## Context`

Two short paragraphs:

- Which apply-skill this subagent slices and which phase / section it
  owns. Cite the path: `.claude/skills/applying-isucon-arch-<slug>/references/ENDPOINTS.md` §"#1 GET /api/app/notification".
- The baseline number that motivates the change, copied from
  `docs/isucon-arch/BASELINE.md` (e.g. "alp sum 18.4s, p99 920ms").

### 3. `## Pre-check`

Bash commands that confirm the dependencies have already merged into the
worktree's history (the worktree is branched off `main` after the
dispatcher's prior-round merges). The subagent aborts with a clear
"depends on X — run dispatcher" message if any pre-check fails. Example:

```markdown
Before doing anything, confirm:

1. `git log --grep="Task: isucon-arch-<slug>/schema-indexes" --oneline`
   prints at least one commit. If empty, abort with the message:
   "Pre-check failed: schema-indexes has not been merged. The dispatcher
   should have ensured this — abort and ask the dispatcher to re-evaluate."
2. `mysql -e "SHOW INDEX FROM rides" <db>` includes
   `idx_rides_user_created`. If absent, abort with the same message.
   (Note: MySQL is shared remote state — this verifies the parent
   subagent actually ran its DDL, not just merged its commit.)
```

The pre-check is the subagent's last line of defense against being fired
out of order. Encode every parent's expected artifact, in both git
(local commit) and remote (DB / config) form when relevant.

### 4. `## Scope`

Explicit list of files this subagent may modify. Two columns: path, why.

```markdown
| Path | Why |
|------|-----|
| `webapp/go/handlers/notification.go` | rewrite getNotification per ENDPOINTS.md §#1 |
| `webapp/go/cache.go` | add chairsByID lookup wrapper |
| `.claude/commands/isucon-arch-<slug>/overview.md` | flip this task's checkbox |
```

The subagent is forbidden from touching any other file. If it discovers it
needs to, abort and ask the dispatcher to revise the decomposition.

### 5. `## Embedded slice`

Paste the relevant excerpt from the apply-skill verbatim. The subagent
cannot read the apply-skill — it sees only what is in this file.

For an endpoint task, paste the endpoint section from `ENDPOINTS.md`
(plan, code sketch, verification). For a schema task, paste the DDL block
and the EXPLAIN expectations. For a cache task, paste the cache-row(s)
from the CACHE.md table plus the warmup sketch.

### 6. `## Steps`

Numbered, imperative. 3–8 steps. Example:

```markdown
1. Read `webapp/go/handlers/notification.go` to locate `getNotification`.
2. Replace the per-ride `SELECT chair WHERE id=?` loop with the IN-query
   pattern shown in the embedded slice.
3. Wire `chairsByID` from `webapp/go/cache.go` (added by `cache-warmup`)
   as the first lookup; fall back to the IN-query on miss.
4. Run the **Verify** block. Iterate until it passes.
5. Run the **Update Overview** block.
6. Run the **Commit** block.
```

### 7. `## Verify`

Executable commands. Every command must be runnable as-is from the repo
root. Each is treated as a hard gate — non-zero exit aborts the subagent.

```markdown
```bash
go build ./...
curl -s http://isu1/api/app/notification -H "Cookie: app_session=$TOKEN" \
  | jq -S . > /tmp/after.json
diff <(jq -S . /tmp/baseline-notification.json) /tmp/after.json   # must be empty
mysql -e "EXPLAIN SELECT * FROM rides WHERE user_id='X' ORDER BY created_at DESC" <db> \
  | grep -q 'idx_rides_user_created'
```
```

If a verify is not yet runnable (e.g. baseline file does not exist), the
subagent records the missing artifact, aborts, and tells the dispatcher.
It does NOT fabricate a passing run.

### 8. `## Update Overview` and `## Commit`

Identical to `writing-implementation-tasks` task commands:

```markdown
## Update Overview

1. Open `.claude/commands/isucon-arch-<slug>/overview.md`.
2. Flip `- [ ] <task-id>: ...` to `- [x] <task-id>: ...` for THIS task only.
3. Stage the edit together with the task's other changes — one atomic commit.

## Commit

After **Verify** passes and **Update Overview** is staged, invoke the
`committing-code` skill to land one atomic commit. The message MUST
include this trailer line so the dispatcher can grep for it:

  Task: isucon-arch-<slug>/<task-id>

Suggested shape:

  perf(isuride): rewrite GET /api/app/notification with chair IN-query

  Implements task endpoint-1-app-notification for isuride.
  Spec: applying-isucon-arch-isuride/references/ENDPOINTS.md §#1
  Task: isucon-arch-isuride/endpoint-1-app-notification
```

The `Task: ...` trailer is **not optional**. The dispatcher uses
`git log --grep="Task: isucon-arch-<slug>/<task-id>"` as the source of
truth for "is this task done".

## Worked example: `endpoint-1-app-notification`

```markdown
---
name: isucon-arch-isuride-endpoint-1-app-notification
description: Rewrites GET /api/app/notification per ENDPOINTS.md §#1 — adds idx_rides_user_created lookup, replaces per-ride chair SELECT with IN-query + chairsByID cache. Do NOT invoke directly — fire only via /isucon-arch-isuride/dispatch.
tools: Bash, Read, Write, Edit, Grep, Glob, Skill
model: sonnet
---

# Endpoint #1 — GET /api/app/notification

## Context

This subagent owns the endpoint redesign captured in
`.claude/skills/applying-isucon-arch-isuride/references/ENDPOINTS.md` §"#1 GET /api/app/notification".

Baseline (`docs/isucon-arch/BASELINE.md`): alp sum 18.4s, p99 920ms;
pt-query-digest #1 (`SELECT * FROM rides WHERE user_id = ?`) accounts
for 14s. The plan removes both lines.

## Pre-check

1. `git log --grep="Task: isucon-arch-isuride/schema-indexes" --oneline` prints ≥ 1.
2. `git log --grep="Task: isucon-arch-isuride/cache-warmup" --oneline` prints ≥ 1.
3. `mysql -e "SHOW INDEX FROM rides" isuride | grep -q idx_rides_user_created`.

If any check fails: abort with "Pre-check failed: schema-indexes / cache-warmup
not committed. Run /isucon-arch-isuride/dispatch."

## Scope

| Path | Why |
|------|-----|
| `webapp/go/handlers/notification.go` | rewrite getNotification |
| `webapp/go/cache.go` | wire chairsByID lookup |
| `.claude/commands/isucon-arch-isuride/overview.md` | checkbox flip |

## Embedded slice

(verbatim copy of ENDPOINTS.md §#1 — plan, code sketch, verification)

## Steps

1. Read `webapp/go/handlers/notification.go`.
2. Apply the embedded code sketch, replacing the per-ride loop.
3. Run **Verify**.
4. Run **Update Overview** and **Commit**.

## Verify

```bash
go build ./...
curl -s http://isu1/api/app/notification -H "Cookie: app_session=$TOKEN" > /tmp/after.json
diff <(jq -S . /tmp/baseline-notification.json) <(jq -S . /tmp/after.json)
mysql -e "EXPLAIN SELECT * FROM rides WHERE user_id='X' ORDER BY created_at DESC" isuride | grep -q idx_rides_user_created
```

## Update Overview

1. Open `.claude/commands/isucon-arch-isuride/overview.md`.
2. Flip `- [ ] endpoint-1-app-notification` to `- [x] endpoint-1-app-notification`.

## Commit

Invoke `committing-code` with:

  perf(isuride): rewrite GET /api/app/notification with chair IN-query

  Implements task endpoint-1-app-notification for isuride.
  Spec: applying-isucon-arch-isuride/references/ENDPOINTS.md §#1
  Task: isucon-arch-isuride/endpoint-1-app-notification
```

## Anti-patterns

- A subagent that says "see the apply-skill for details" — defect, embed it.
- A subagent that edits files outside Scope to "fix what it found" —
  defect, the dispatcher must re-decompose instead.
- A subagent without a runnable Verify — defect, the dispatcher cannot
  trust its commit.
- A subagent without the `Task: ...` trailer in its commit message —
  defect, the dispatcher cannot detect completion.
- A subagent that auto-invokes on a vague user message — defect, the
  description must include "Do NOT invoke directly".
