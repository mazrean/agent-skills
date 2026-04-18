---
name: writing-implementation-tasks
description: Creates implementation tasks as Claude Code custom slash commands with dependency ordering and atomic scope. Use when breaking down features into executable task commands, planning implementation order, defining task dependencies, or when user mentions task breakdown, implementation plan, or work decomposition for spec-driven development.
---

# Writing Implementation Tasks as Commands

Create implementation task breakdowns as Claude Code custom slash commands. Each task becomes an invokable `/command` that guides the agent through a single atomic implementation step.

**Use this skill when** breaking a feature spec and technical design into implementable tasks, planning implementation order, or defining what to build next.

**Supporting files:** [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) for layer mapping details, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Why Commands?

Implementation tasks as Claude Code commands provide:
- **On-demand execution**: User runs `/task-1-data-model` to start a specific task
- **Self-contained context**: Each command has all info needed for that task
- **Clear workflow**: Progress tracked via a overview command
- **No wasted tokens**: Only the current task is loaded, not the full task list

## Output Structure

```
.claude/commands/{feature-name}/
├── overview.md                     # Progress tracker, run with /{feature-name}/overview
├── task-1-{short-name}.md          # Task 1 command
├── task-2-{short-name}.md          # Task 2 command
├── task-3-{short-name}.md          # Task 3 command
└── ...
```

## Template: Overview Command

`.claude/commands/{feature-name}/overview.md`

```markdown
---
description: Show progress and next steps for {Feature Name} implementation
allowed-tools: Read, Glob, Grep
---

# {Feature Name} - Implementation Overview

<background_information>
- **PRD**: skills/prd-{feature-name}/SKILL.md
- **Design**: specs/design-{feature-name}.md (if exists)
- **Mission**: Track implementation progress and guide to next task
</background_information>

<instructions>
## Execution Steps

1. Check the status of each task file in `.claude/commands/{feature-name}/`
2. For each task, check if the "Done when" verification commands pass
3. Report progress summary and recommend the next task to run

## Progress

- [ ] Task 1: {title} → `/{feature-name}/task-1-{short-name}`
- [ ] Task 2: {title} → `/{feature-name}/task-2-{short-name}`
- [ ] Task 3: {title} → `/{feature-name}/task-3-{short-name}`
- [ ] Task 4: {title} → `/{feature-name}/task-4-{short-name}`

## Dependency Order

```
Task 1 (no deps)
  └─► Task 2 (depends: Task 1)
       └─► Task 3 (depends: Task 2)
            └─► Task 4 (depends: Task 2, Task 3)
```
</instructions>

## Output Description
Report: which tasks are done, which is next, and the command to run it.
```

## Template: Task Command

`.claude/commands/{feature-name}/task-{N}-{short-name}.md`

```markdown
---
description: {Task title} for {Feature Name}
allowed-tools: Bash, Read, Write, Edit, Glob, Grep
---

# Task {N}: {Title}

<background_information>
- **PRD**: skills/prd-{feature-name}/SKILL.md
- **Design**: specs/design-{feature-name}.md
- **Depends on**: {Task M title} (task-{M}-{short-name})
- **Spec refs**: {FR-1, FR-2, ...}
</background_information>

<instructions>
## Core Task

{Concise implementation instructions. 3-10 lines.
Reference interface contracts from design doc, not repeat them.}

## Scope

Files to create or modify:
- `{path/to/file1}`
- `{path/to/file2}`

Do NOT modify files outside this scope.

## Steps

1. {Step 1}
2. {Step 2}
3. {Step 3}
</instructions>

## Done When

Run these verification commands. ALL must pass before this task is complete:

```bash
{verification command 1}
{verification command 2}
```

## Safety & Fallback

- If verification fails, fix and re-run — do not skip
- If blocked by a dependency, report which task must be completed first
- Do not modify files outside the defined scope
```

## Writing Guidelines

### Task Scope: Atomic and Committable

Each task command must be completable in a single atomic commit:

```markdown
<!-- BAD: Too broad -->
## Core Task
Implement the notification system

<!-- GOOD: Specific files, clear boundary -->
## Core Task
Create `internal/notification/model.go` (types) and
`migrations/005_notifications.sql` (DDL from design doc)

## Scope
- `internal/notification/model.go`
- `migrations/005_notifications.sql`
```

### Task Ordering: Dependency-Driven

Order tasks so each builds on the previous. Follow bottom-up pattern:

```
task-1-data-model       (no dependencies)
task-2-repository       (depends: task-1)
task-3-service          (depends: task-2)
task-4-handler          (depends: task-3)
task-5-integration      (depends: all above)
task-6-tests            (depends: task-5)
```

### Spec References: Link, Don't Repeat

Tasks reference requirement IDs and design components:

```markdown
## Core Task

Implement the NotificationSender interface defined in
specs/design-notifications.md (Component: Notification Sender).
Follow the interface contract exactly. Use FCM SDK for Android
delivery per Decision Summary.
```

### Verification: Executable Checks

Every task's "Done When" must be runnable commands:

```markdown
## Done When

```bash
go test ./internal/notification/model/...
sqlc generate
go vet ./...
```
```

### Command Description: Clear and Actionable

The `description` field in frontmatter drives command discovery:

```yaml
# BAD: vague
description: Do task 1

# GOOD: specific
description: Create notification data model and database migrations for push notifications
```

## Task Granularity Guide

| Task size | Lines of code | Good for |
|-----------|--------------|----------|
| Too small | < 20 LOC | Merge into adjacent task |
| Right size | 20-200 LOC | Single focused change |
| Too large | > 200 LOC | Split into sub-tasks |

Signs a task is too large:
- Instructions exceed 15 lines
- Scope spans 3+ unrelated directories
- Multiple independent verification steps

Signs a task is too small:
- Just creating a single type definition
- Only adding an import
- Purely mechanical rename/move

## Handling Blocked Tasks

When a task depends on incomplete work, the command should detect and report it:

```markdown
<instructions>
## Pre-check

Before starting, verify dependencies are complete:
1. Check that `internal/notification/model.go` exists (from Task 1)
2. If missing, report: "Task 1 must be completed first. Run /{feature}/task-1-data-model"
</instructions>
```

## Lifecycle

```
1. Start from approved feature spec (Agent Skill) + technical design
2. Identify implementation units from components in design doc
3. Order tasks by dependency (bottom-up)
4. Create .claude/commands/{feature}/ directory
5. Write overview.md with progress checklist
6. Write each task-{N}-{short-name}.md with scope, steps, verification
7. User runs /{feature}/overview to see status
8. User runs /{feature}/task-{N}-{short-name} to implement each task
9. After all tasks done, optionally archive or remove command directory
```

## Quality Checklist

```
Implementation Tasks (Commands) Quality Check:
- [ ] Directory: .claude/commands/{feature-name}/
- [ ] overview.md exists with progress checklist and dependency graph
- [ ] Each task is a separate command file: task-{N}-{short-name}.md
- [ ] Each command has frontmatter: description, allowed-tools
- [ ] Tasks ordered by dependency (bottom-up)
- [ ] Each task has: background_information, instructions, done-when
- [ ] Each task is atomic (single commit, 20-200 LOC)
- [ ] Instructions reference spec/design, don't repeat them
- [ ] "Done When" has executable verification commands
- [ ] No task spans 3+ unrelated directories
- [ ] Scope section explicitly lists files to create/modify
- [ ] Pre-check verifies dependencies before starting
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete task breakdown examples**: See [EXAMPLES.md](references/EXAMPLES.md)
