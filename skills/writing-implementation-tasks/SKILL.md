---
name: writing-implementation-tasks
description: Creates agent-optimized implementation task breakdowns with dependency ordering and atomic scope. Use when breaking down features into tasks, planning implementation order, defining task dependencies, or when user mentions task breakdown, implementation plan, or work decomposition for spec-driven development.
---

# Writing Implementation Tasks

Create task breakdowns that guide coding agents through implementation in the correct order. Each task is scoped for a single atomic commit with clear inputs, outputs, and verification.

**Use this skill when** breaking a feature spec and technical design into implementable tasks, planning implementation order, or defining what to build next.

**Supporting files:** [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) for layer mapping details, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Context Layer Distribution

Task information spans context layers differently from other spec documents:

```
Layer   What goes here              File location
======================================================================
L1      Current task status         CLAUDE.md / AGENTS.md (constitution)
        "Current: Task 3 of specs/tasks-notifications.md"

L2      (Not typically used for tasks)

L3      Task list (this doc)        specs/tasks-{feature}.md
        Ordered tasks with scope, deps, verification

L4      Task details                specs/tasks-{feature}.md (per-task)
        Detailed implementation notes, edge cases
======================================================================

Key difference: L1 tracks CURRENT POSITION, not the full task list.
The agent loads L3 only to pick the next task or check dependencies.
```

## Template: `specs/tasks-{feature-name}.md`

```markdown
---
title: "Feature Name - Implementation Tasks"
status: in-progress | blocked | done
prd: prd-feature-name.md
design: design-feature-name.md
last-updated: YYYY-MM-DD
---

# Feature Name - Implementation Tasks

## Progress

- [x] Task 1: [title]
- [x] Task 2: [title]
- [ ] Task 3: [title]  <-- current
- [ ] Task 4: [title]
- [ ] Task 5: [title]

## Task 1: [Title]

- **Status**: done
- **Depends on**: none
- **Spec refs**: FR-1
- **Scope**: [What files/components to create or modify]
- **Verify**: [Command to run or condition to check]

### What to do

[Concise implementation instructions. 3-10 lines.
Reference interface contracts from design doc, not repeat them.]

### Done when

- [ ] [Concrete verification 1: e.g., "tests pass: go test ./internal/notification/..."]
- [ ] [Concrete verification 2: e.g., "endpoint returns 200 with valid payload"]

---

## Task 2: [Title]

- **Status**: done
- **Depends on**: Task 1
- **Spec refs**: FR-2
- **Scope**: `internal/notification/sender/`
- **Verify**: `go test ./internal/notification/sender/...`

### What to do

[Instructions]

### Done when

- [ ] [Verification]

---

## Task 3: [Title]

- **Status**: in-progress
- **Depends on**: Task 1, Task 2
- **Spec refs**: FR-3, FR-4
- **Scope**: `internal/handler/notification.go`, `internal/notification/service.go`
- **Verify**: `go test ./internal/handler/... ./internal/notification/...`

### What to do

[Instructions]

### Done when

- [ ] [Verification]
```

## Writing Guidelines

### Progress Section: The Agent's Navigation

The Progress section at the top serves as a quick-scan index. Agents read this first to:
1. Find the current task
2. Understand overall completion state
3. Decide whether to load task details

```markdown
## Progress

- [x] Task 1: Define notification data model and migrations
- [x] Task 2: Implement NotificationSender interface
- [ ] Task 3: Wire up order status change events  <-- current
- [ ] Task 4: Add push notification delivery (FCM/APNs)
- [ ] Task 5: Integration tests and error handling
```

The `<-- current` marker tells the agent exactly where to focus.

### Task Scope: Atomic and Committable

Each task must be completable in a single atomic commit. The scope definition prevents agents from touching unrelated code:

```markdown
<!-- BAD: Too broad, agent will over-engineer -->
- **Scope**: Implement the notification system

<!-- GOOD: Specific files, clear boundary -->
- **Scope**: Create `internal/notification/model.go` (types) and
  `migrations/005_notifications.sql` (DDL from design doc)
```

### Task Ordering: Dependency-Driven

Order tasks so each builds on the previous. The dependency chain should follow a bottom-up pattern:

```
1. Data model / types       (no dependencies)
2. Repository / storage     (depends on: types)
3. Business logic / service (depends on: repository)
4. API handlers / transport (depends on: service)
5. Integration / wiring     (depends on: all above)
6. Tests / verification     (depends on: wiring)
```

### Spec References: Link, Don't Repeat

Tasks reference requirement IDs and design components, not repeat their content:

```markdown
### What to do

Implement the NotificationSender interface defined in
specs/design-notifications.md (Component: Notification Sender).
Follow the interface contract exactly. Use FCM SDK for Android
delivery per Decision Summary.
```

The agent loads the referenced design doc section only if needed for implementation details.

### Verification: Executable Checks

Every task's "Done when" must be verifiable by running a command:

```markdown
### Done when

- [ ] `go test ./internal/notification/model/...` passes
- [ ] `sqlc generate` succeeds without errors
- [ ] `go vet ./...` reports no issues
```

Agents run these commands after implementation to self-verify.

## L1 Integration: Current Task Tracking

Keep the constitution updated with current task position:

```markdown
<!-- In CLAUDE.md / AGENTS.md -->
## Current Work

Working on: specs/tasks-notifications.md, Task 3
Next: Task 4 (push delivery via FCM/APNs)
```

This costs ~30 tokens but gives the agent immediate context on session start. Update this as tasks complete.

## Task Granularity Guide

| Task size | Lines of code | Good for |
|-----------|--------------|----------|
| Too small | < 20 LOC | Merge into adjacent task |
| Right size | 20-200 LOC | Single focused change |
| Too large | > 200 LOC | Split into sub-tasks |

Signs a task is too large:
- "What to do" exceeds 15 lines
- Scope spans 3+ unrelated directories
- Multiple independent verification steps

Signs a task is too small:
- Just creating a single type definition
- Only adding an import
- Purely mechanical rename/move

## Handling Blocked Tasks

When a task is blocked, mark it and note the blocker:

```markdown
## Task 4: Add push notification delivery

- **Status**: blocked
- **Blocked by**: Waiting for FCM credentials from DevOps (@alice)
- **Depends on**: Task 2
```

The agent skips blocked tasks and moves to the next unblocked one.

## Lifecycle

```
1. Start from approved feature spec + technical design
2. Identify implementation units from components in design doc
3. Order tasks by dependency (bottom-up)
4. Write each task with scope, verification, and done-when
5. Set first task as current in constitution (L1)
6. Agent implements Task 1, marks done, updates L1 to Task 2
7. Repeat until all tasks done
8. Set task doc status: "done"
9. Update feature spec status: "done"
10. Remove L1 current-work reference (save tokens)
```

## Quality Checklist

```
Implementation Tasks Quality Check:
- [ ] Links to both feature spec and technical design in frontmatter
- [ ] Progress section at top with checkbox list
- [ ] Current task marked with <-- current
- [ ] Tasks ordered by dependency (bottom-up)
- [ ] Each task has: status, depends-on, spec-refs, scope, verify
- [ ] Each task is atomic (single commit, 20-200 LOC)
- [ ] "What to do" references spec/design, doesn't repeat them
- [ ] "Done when" has executable verification commands
- [ ] No task spans 3+ unrelated directories
- [ ] Current task tracked in constitution (L1)
- [ ] File named: specs/tasks-{feature-name}.md
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete task breakdown examples**: See [EXAMPLES.md](references/EXAMPLES.md)
