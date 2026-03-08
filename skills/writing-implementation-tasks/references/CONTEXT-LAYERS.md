# Implementation Tasks Context Layer Mapping

Detailed guide on distributing task information across context layers.

## Layer Distribution for Task Documents

```
                    Token Cost
Layer   Frequency   Per Request   Purpose
=============================================
L1      Every req   ~30 tokens    Current task pointer
L2      (rarely)    N/A           Tasks don't usually need L2
L3      On demand   ~600 tokens   Task list + current task details
L4      Per task    ~200 tokens   Implementation notes per task
=============================================
```

## L1: Current Task Pointer

**What goes here:** A single line identifying what the agent should work on right now.

**Why this is critical:** Without L1 tracking, the agent must:
1. Search for the task document
2. Read the full task list
3. Determine which task is current
4. Then start working

With L1 tracking, the agent knows immediately on session start.

**Format in CLAUDE.md / AGENTS.md:**
```markdown
## Current Work

Working on: specs/tasks-notifications.md, Task 3 (Wire up order status events)
Next: Task 4 (Push delivery via FCM/APNs)
```

**Update cadence:**
- Update L1 when completing a task and moving to the next
- Remove L1 entry when all tasks are done
- If blocked, update to show blocked status and next unblocked task

**Token cost:** ~30 tokens. Worth the cost because it saves the agent from loading and scanning the full task document on every session start.

## L2: Rarely Used for Tasks

Tasks don't usually generate path-conditional rules because they're temporary (done once, then completed). However, there's one exception:

**Temporary coding constraints during multi-task implementation:**
```markdown
<!-- .claude/rules/wip-notification-migration.md -->
---
paths:
  - "internal/notification/**/*.go"
---

WIP: Notification system is under construction (specs/tasks-notifications.md).
- Tasks 1-2 are complete: data model and sender interface exist
- Task 3 in progress: event wiring
- Do NOT add direct FCM calls; use NotificationSender interface
- Consumer is not yet deployed; events are queued but not processed
```

Remove this L2 file after all tasks are complete.

## L3: Task List Structure

The task list is the primary L3 content. It's loaded when the agent needs to:
- Find the current task's details
- Check dependencies before starting
- Verify what's already done

**Optimized structure for agent consumption:**

```
1. Progress checklist (50 tokens)
   Quick scan: what's done, what's current, what's ahead.
   Agent reads this FIRST.

2. Current task details (200 tokens)
   Full instructions for the task marked as current.
   Agent reads this SECOND.

3. Next task preview (100 tokens)
   Brief look at what comes after current.
   Agent reads to understand context.

4. Completed tasks (summary only) (100 tokens)
   Collapsed or minimal. Agent rarely needs these.

5. Future tasks (brief) (150 tokens)
   Title + dependencies only. Not full details.
```

**Total L3 budget:** ~600 tokens when loading the document.

## Task Status Lifecycle

```
                ┌──────────┐
                │  pending  │
                └────┬─────┘
                     │ dependencies met
                ┌────▼─────┐
           ┌────│in-progress│
           │    └────┬─────┘
           │         │
     ┌─────▼──┐ ┌───▼────┐
     │blocked │ │  done   │
     └────┬───┘ └────────┘
          │ unblocked
          └──────────┘ (back to in-progress)
```

**L1 constitution should reflect:**
- `in-progress`: "Working on: Task N"
- `blocked`: "Blocked: Task N (reason). Working on: Task M instead"
- `done` (all tasks): Remove current work section

## Task Completion Protocol

When the agent completes a task:

```
1. Run verification commands from "Done when" section
2. If all pass:
   a. Mark task checkbox as [x] in Progress section
   b. Set task status to "done"
   c. Update L1 constitution to point to next task
   d. Commit changes
3. If verification fails:
   a. Fix the issue
   b. Re-run verification
   c. Do NOT mark as done until verification passes
```

## Dependency Resolution

Agents should check dependencies before starting a task:

```markdown
## Task 3: Wire up order status events

- **Status**: pending
- **Depends on**: Task 1, Task 2
```

**Agent behavior:**
1. Read Progress section
2. Verify Task 1 and Task 2 are marked `[x]`
3. If not, find the first incomplete dependency and work on that instead
4. If all dependencies are done, start Task 3

## Parallel Task Execution

Some tasks can be parallelized. Mark them explicitly:

```markdown
## Progress

- [x] Task 1: Data model
- [ ] Task 2: FCM sender       (parallel group A)
- [ ] Task 3: APNs sender      (parallel group A)
- [ ] Task 4: Consumer wiring  (depends on: Task 2, Task 3)
```

For agents, "parallel" means these tasks have no dependencies on each other and can be done in any order. A single agent works sequentially, but this signals that Task 2 and Task 3 won't conflict.

## Collapsed Completed Tasks

Once tasks are done, collapse their details to save tokens when the document is loaded:

```markdown
## Task 1: Define notification data model

- **Status**: done
- **Commit**: abc1234

<!-- Details collapsed after completion.
     Full details available in git history. -->
```

This keeps the document lean as tasks accumulate. The agent only needs to see that it's done and can check git history if needed.
