# Implementation Tasks Context Layer Mapping (Command Edition)

Detailed guide on how implementation task commands interact with context layers.

## Commands and Context Layers

```
                    Token Cost
Layer   Frequency      Per Request   Purpose
====================================================================
L1      Every req      0 tokens      No L1 footprint (commands are on-demand)
L2      (rarely)       N/A           Tasks don't usually need L2
L3      On invoke      ~400 tokens   Single task command content
L3'     Skill match    ~400 tokens   Auto-loaded per-component research digest
                                      (skills/tech-{component}/SKILL.md —
                                      triggered by the files the task edits)
L4      Per ref        ~200 tokens   Design doc / PRD sections
L4'     Explicit       varies        Component deep reference
                                      (skills/tech-{component}/references/)
====================================================================
```

**Key difference from files:** Commands have zero L1 cost. They're only loaded when the user invokes them with `/{feature}/task-{N}-{name}`.

**Why L3' matters for tasks:** a task command is small by design (~400 tokens). When it touches, say, `internal/notification/consumer/`, Claude auto-discovers `skills/tech-redis-streams/SKILL.md` via its description and loads the research digest alongside the task instructions. The task command itself does not need to restate API signatures, pitfalls, or version constraints — that content is carried by the component skill, on demand.

## L1: Not Used

Commands have no L1 footprint. Unlike skills or constitution entries, commands are not indexed or auto-discovered — they're explicitly invoked by the user.

**Advantage:** No token cost when not in use. No need to maintain constitution references.

**Trade-off:** User must know the command name. The overview command (`/{feature}/overview`) serves as the entry point for discovery.

## L2: Rarely Used for Tasks

Tasks don't usually generate path-conditional rules because they're temporary. However, there's one exception:

**Temporary coding constraints during multi-task implementation:**
```markdown
<!-- .claude/rules/wip-notification-migration.md -->
---
paths:
  - "internal/notification/**/*.go"
---

WIP: Notification system is under construction.
- Tasks 1-2 are complete: data model and sender interface exist
- Do NOT add direct FCM calls; use NotificationSender interface
- Consumer is not yet deployed; events are queued but not processed
```

Remove this L2 file after all tasks are complete.

## L3: Single Task Content (On Invoke)

When the user runs a task command, only that task's content is loaded. This is the primary advantage of commands over a single task file.

**Comparison:**

| Approach | Tokens loaded per task |
|----------|----------------------|
| Single tasks file | ~600 tokens (full file) |
| Command per task | ~400 tokens (just this task) |

**Command structure for optimal L3:**

```
1. background_information (50 tokens)
   PRD/design links, dependencies, spec refs.

2. instructions (200 tokens)
   Pre-check, core task, scope, steps.

3. Done When (50 tokens)
   Executable verification commands.

4. Safety & Fallback (50 tokens)
   Error handling and dependency checks.
```

**Total L3 budget:** ~350-400 tokens per task command.

## L3': Auto-Discovered Component Skills

Unlike L4 references (which a task command *names*), L3' content is discovered automatically from skill metadata. The task command does not need to list `tech-{component}` skills explicitly — Claude activates them based on the files the task edits and the topics the task mentions.

**How it works:**
1. Task command instructs the agent to edit `internal/notification/consumer/consumer.go`.
2. Claude's skill index matches the file path against the `description` field of `skills/tech-redis-streams/SKILL.md` ("files under internal/notification/consumer/").
3. That skill's body (API subset, pitfalls, integration pattern) loads alongside the task command.

**What this lets the task command omit:**
- Redis Stream API signatures → covered by `tech-redis-streams`
- FCM retry semantics → covered by `tech-fcm-android`
- Version-specific SQL feature notes → covered by `tech-postgres-*`

**Surfacing the link (optional but helpful):** if the task relies on a specific component skill for correctness, mention it in `background_information` so a human reader can follow the same trail:

```markdown
<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Component research**: skills/tech-redis-streams/SKILL.md (auto-loaded)
- **Spec refs**: FR-1, FR-3
</background_information>
```

## L4: Referenced Documents

Task commands reference external documents (PRD skill, design doc, `tech-{component}/references/`) rather than including their content. The agent loads these only when needed.

**Loading trigger:** The agent loads L4 content when:
- Interface contracts are needed from the design doc
- Requirements need clarification from the PRD skill
- Extended API tables or benchmarks are needed from `tech-{component}/references/` (L4')
- A step references a section in another document

**Example references in a task command:**
```markdown
<background_information>
- **PRD**: skills/prd-notifications/SKILL.md
- **Design**: specs/design-notifications.md
- **Component research**: skills/tech-redis-streams/SKILL.md (auto-loaded when editing consumer/)
- **Spec refs**: FR-1, FR-3
</background_information>
```

The agent reads these files only if the instructions alone aren't sufficient.

## Overview Command: The Navigation Layer

The overview command (`/{feature}/overview`) serves a unique role — it's the only command that sees all tasks at once:

```markdown
## Progress

- [x] Task 1: Data model → `/notifications/task-1-data-model`
- [x] Task 2: Sender interface → `/notifications/task-2-sender-interface`
- [ ] Task 3: Event wiring → `/notifications/task-3-event-wiring`  ← next
- [ ] Task 4: Push delivery → `/notifications/task-4-push-delivery`
- [ ] Task 5: Consumer → `/notifications/task-5-consumer`
- [ ] Task 6: Integration tests → `/notifications/task-6-integration-tests`
```

**Token cost:** ~200 tokens for the overview. Loaded only when the user asks for status.

## Task Status Lifecycle

```
User runs /{feature}/overview
  → Sees progress, gets next task recommendation
  → Runs /{feature}/task-{N}-{name}
    → Agent checks pre-conditions (dependencies)
    → Agent implements the task
    → Agent runs verification commands
    → Reports completion
  → User runs /{feature}/overview again
    → Updated progress shown
```

**No constitution updates needed.** Unlike the file-based approach, there's no L1 entry to maintain. The overview command checks actual code state to determine completion.

## Dependency Resolution

Each task command includes a pre-check section:

```markdown
## Pre-check

Before starting, verify dependencies are complete:
1. Check that `internal/notification/model.go` exists (from Task 1)
2. If missing, report: "Task 1 must be completed first.
   Run /notifications/task-1-data-model"
```

**Agent behavior:**
1. Run pre-check before starting implementation
2. If dependencies are missing, report which task to run first
3. If all dependencies are met, proceed with implementation

## Parallel Task Execution

Some tasks can be run independently. Note this in the overview:

```markdown
## Dependency Order

Task 1: Data model (no deps)
├─► Task 2: Sender interface (depends: Task 1)
├─► Task 3: Event wiring (depends: Task 1)     ← parallel with Task 2
```

Tasks 2 and 3 can be run in any order after Task 1 completes.

## Completed Task Cleanup

After all tasks are done, the command directory can be:
- **Kept**: For reference, commands are zero-cost when not invoked
- **Archived**: Move to `.claude/commands/_archive/{feature}/`
- **Removed**: Delete the directory entirely

Since commands have zero L1 cost, there's no urgency to clean up.
