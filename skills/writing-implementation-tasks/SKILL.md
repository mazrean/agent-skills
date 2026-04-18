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
allowed-tools: Bash, Read, Glob, Grep
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
2. For each task, determine completion by BOTH:
   - The **Verify** commands pass
   - A commit exists for the task (check `git log --grep="Task {N}"` or
     matching Conventional Commits message for that task)
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
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, Skill
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

## Verify

Run these verification commands. ALL must pass before moving on:

```bash
{verification command 1}
{verification command 2}
```

If verification fails, fix and re-run — do not proceed to commit.

## Commit

After verification passes, commit the work as a single atomic commit using the
`committing-code` skill (Conventional Commits format).

1. Review staged scope: `git status` and `git diff` — confirm only the files
   listed in **Scope** are changed.
2. Invoke the `committing-code` skill to produce and execute the commit.
3. Suggested message shape (adjust type/scope to match the change):

   ```text
   {type}({feature-name}): {one-line imperative summary of Task {N}}

   Implements Task {N} ({short-name}) for {Feature Name}.
   Spec refs: {FR-1, FR-2, ...}
   ```

4. Verify the commit landed: `git log -1 --stat`.
</instructions>

## Done When

- [ ] All **Verify** commands pass
- [ ] `git status` is clean (no uncommitted changes in task scope)
- [ ] `git log -1` shows the task commit with a Conventional Commits message

## Safety & Fallback

- If verification fails, fix and re-run — do not commit a broken state
- If blocked by a dependency, report which task must be completed first and
  do NOT create a commit
- Do not modify files outside the defined scope
- Do not amend or rewrite prior task commits — each task is its own commit
- If unrelated changes are already staged, unstage them before committing
```

## Writing Guidelines

### Task Scope: Atomic and Committable

Each task command must be completable in a single atomic commit — and the
command itself must end by creating that commit via the `committing-code`
skill. Tasks without a commit step are incomplete:

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

Every task's **Verify** section must be runnable commands:

```markdown
## Verify

```bash
go test ./internal/notification/model/...
sqlc generate
go vet ./...
```
```

### Commit: Atomic, Conventional, Skill-Driven

Every task ends with a commit step that delegates to `committing-code`:

```markdown
## Commit

After verification passes, invoke the `committing-code` skill to create a
single atomic commit. Suggested message:

  feat(notifications): add notification data model and migration

  Implements Task 1 (data-model) for Push Notifications.
  Spec refs: FR-1, FR-5
```

Rules:
- One task = one commit. Never batch multiple tasks into one commit.
- Follow Conventional Commits (see `committing-code` skill).
- If staged diff covers files outside Scope, unstage them before committing.
- Do not amend prior task commits — create a new commit per task.

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
5. Write overview.md with progress checklist (tracks verify + commit)
6. Write each task-{N}-{short-name}.md with scope, steps, verify, commit
7. User runs /{feature}/overview to see status
8. User runs /{feature}/task-{N}-{short-name}:
   a. Pre-check dependencies
   b. Execute Steps
   c. Run Verify commands (all must pass)
   d. Commit via committing-code skill (one atomic commit per task)
9. After all tasks done, optionally archive or remove command directory
```

## Quality Checklist

```
Implementation Tasks (Commands) Quality Check:
- [ ] Directory: .claude/commands/{feature-name}/
- [ ] overview.md exists with progress checklist and dependency graph
- [ ] Each task is a separate command file: task-{N}-{short-name}.md
- [ ] Each command has frontmatter: description, allowed-tools (includes Skill)
- [ ] Tasks ordered by dependency (bottom-up)
- [ ] Each task has: background_information, instructions, Verify, Commit, Done When
- [ ] Each task is atomic (single commit, 20-200 LOC)
- [ ] Instructions reference spec/design, don't repeat them
- [ ] "Verify" has executable verification commands
- [ ] "Commit" invokes the committing-code skill and proposes a Conventional
      Commits message referencing the task number and spec refs
- [ ] "Done When" checks both verify passing AND commit landed
- [ ] No task spans 3+ unrelated directories
- [ ] Scope section explicitly lists files to create/modify
- [ ] Pre-check verifies dependencies before starting
- [ ] Safety & Fallback forbids amending prior commits and committing broken state
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete task breakdown examples**: See [EXAMPLES.md](references/EXAMPLES.md)
