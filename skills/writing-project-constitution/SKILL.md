---
name: writing-project-constitution
description: Creates project constitution files (CLAUDE.md/AGENTS.md) that serve as always-loaded context for coding agents. Use when setting up a new project for spec-driven development, configuring agent instructions, writing CLAUDE.md or AGENTS.md, or establishing project-wide coding standards and constraints.
---

# Writing Project Constitution

Create constitution files (CLAUDE.md / AGENTS.md) that are **always loaded into the agent's context window on every request**. This is the most expensive context layer -- every token here is consumed on every interaction.

**Use this skill when** initializing a project for spec-driven development, writing CLAUDE.md or AGENTS.md, or defining always-applicable project rules.

**Supporting files:** [CROSS-AGENT.md](references/CROSS-AGENT.md) for agent-specific file placement, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Context Layer: L1 (Always Loaded)

```
Context Loading Timeline
================================================================
Session Start    Task Start    Implementation    Deep Dive
     |
     +-- CLAUDE.md / AGENTS.md  <-- THIS SKILL
     |   (loaded EVERY request, costs tokens EVERY time)
     |
     +-- Skill descriptions (metadata only)
================================================================
```

The constitution is the **only document that persists across context compression**. When the agent's conversation gets too long, older messages are compressed, but the constitution is re-injected. This makes it the right place for information that must NEVER be forgotten.

## What Belongs Here (and What Does NOT)

### MUST include (needed every request):

- Build / test / lint commands
- Tech stack summary (one line per technology)
- Core coding conventions (naming, error handling style)
- Hard constraints ("never commit secrets", "always run tests")
- Active feature spec references (one line each)
- Directory structure overview (abbreviated)

### MUST NOT include (move elsewhere):

| Information | Move to | Reason |
|-------------|---------|--------|
| Detailed requirements | Feature spec (L3/L4) | Only needed during implementation |
| Architecture decisions | Technical design (L3/L4) | Only needed during design |
| API endpoint details | Path-conditional rules (L2) | Only needed for specific files |
| Task lists | Implementation tasks (L3) | Only needed when selecting work |
| Code examples > 5 lines | Agent Skill references (L4) | Too expensive for L1 |
| Library documentation | MCP or references (L4) | Agent can look up on demand |

## Template

```markdown
# Project Constitution

## Commands

- Build: `[command]`
- Test: `[command]`
- Test single: `[command with placeholder]`
- Lint: `[command]`
- Format: `[command]`

## Tech Stack

- Language: [e.g., Go 1.23]
- Framework: [e.g., Echo v4]
- Database: [e.g., PostgreSQL 16 via sqlc]
- Frontend: [e.g., templ + htmx]

## Project Structure

```
src/           # Application source
internal/      # Private packages
cmd/           # Entry points
specs/         # Feature specs and designs (see below)
```

## Coding Standards

- [Convention 1: e.g., Use snake_case for DB columns, camelCase for Go]
- [Convention 2: e.g., Errors must wrap with fmt.Errorf("context: %w", err)]
- [Convention 3: e.g., All public functions must have godoc comments]

## Boundaries

- ALWAYS: Run tests before considering implementation complete
- ALWAYS: Follow existing patterns in the codebase
- ASK FIRST: Database schema changes, new dependencies
- NEVER: Commit .env files, modify CI config, use force push

## Active Specs

Current feature specs (load these when working on related code):

- `specs/prd-notifications.md` - Push notification system
- `specs/design-notifications.md` - Notification architecture
- `specs/tasks-notifications.md` - Implementation tasks

## Conditional Rules

Code-area-specific rules are in:
- `.claude/rules/` (Claude Code)
- `.github/instructions/` (Copilot CLI)

These load automatically when touching matching files.
```

## Size Budget

**Target: under 200 lines / ~2000 tokens.**

Every line in the constitution costs tokens on every single request. Measure ruthlessly:

```
Good constitution (150 lines):
- 10 lines: commands
- 5 lines: tech stack
- 10 lines: project structure
- 15 lines: coding standards
- 10 lines: boundaries
- 10 lines: active specs
- Remaining: breathing room

Bad constitution (500+ lines):
- 50 lines: detailed API documentation  -> move to L4
- 100 lines: code examples              -> move to L4
- 80 lines: architecture decisions       -> move to L3/L4
- 200 lines: task lists                  -> move to L3
```

## Cross-Agent File Placement

The same content maps to different files per agent:

| Agent | Primary File | Location |
|-------|-------------|----------|
| Claude Code | `CLAUDE.md` | Project root |
| Codex CLI | `AGENTS.md` | Project root |
| Copilot CLI | `AGENTS.md` + `.github/copilot-instructions.md` | Project root |
| Multi-agent | Both `CLAUDE.md` and `AGENTS.md` | Project root |

For multi-agent projects, create both files. They can share content or reference each other. See [CROSS-AGENT.md](references/CROSS-AGENT.md) for detailed patterns.

## Path-Conditional Rules (L2 Layer)

Move area-specific rules out of the constitution into conditional files:

### Claude Code: `.claude/rules/`

```markdown
<!-- .claude/rules/api-handlers.md -->
---
paths:
  - "internal/handler/**/*.go"
  - "internal/api/**/*.go"
---

API handler conventions:
- Use echo.Context for HTTP handling
- Return HTTP errors via echo.NewHTTPError()
- Validate request body with validator tags
- Log with structured logger (slog)
```

### Copilot CLI: `.github/instructions/`

```markdown
<!-- .github/instructions/api-handlers.instructions.md -->
---
applyTo: "internal/handler/**/*.go,internal/api/**/*.go"
---

API handler conventions:
- Use echo.Context for HTTP handling
...
```

### Codex CLI: Subdirectory `AGENTS.md`

```markdown
<!-- internal/handler/AGENTS.md -->
API handler conventions:
- Use echo.Context for HTTP handling
...
```

## Integration with Other Spec Documents

The constitution is the **hub** that links to other documents. Keep references minimal:

```markdown
## Active Specs

- `specs/prd-{feature}.md` - What to build (load via feature-spec skill)
- `specs/design-{feature}.md` - How to build (load via technical-design skill)
- `specs/tasks-{feature}.md` - Implementation order (load via implementation-tasks skill)
```

Agents use these references to know which files to load when starting work on a feature.

## Workflow

```
1. Create CLAUDE.md (and/or AGENTS.md) at project root
2. Add build/test commands first (most universally needed)
3. Add tech stack summary (one line per technology)
4. Add coding standards (only project-specific ones)
5. Add boundaries (always/ask-first/never)
6. Extract area-specific rules to L2 conditional files
7. Add active spec references as features are planned
8. Review total line count -- cut anything over 200 lines
9. Validate: read the file and ask "is EVERY line needed on EVERY request?"
```

## Quality Checklist

```
Constitution Quality Check:
- [ ] Under 200 lines total
- [ ] Build/test/lint commands are present and correct
- [ ] No detailed requirements (those belong in feature specs)
- [ ] No architecture decisions (those belong in technical designs)
- [ ] No task lists (those belong in implementation tasks)
- [ ] No code examples longer than 5 lines
- [ ] Area-specific rules extracted to L2 conditional files
- [ ] Active spec references are current (no stale links)
- [ ] Every line passes the test: "needed on EVERY request?"
```

## Detailed Guides

**Cross-agent file placement**: See [CROSS-AGENT.md](references/CROSS-AGENT.md)
**Complete constitution examples**: See [EXAMPLES.md](references/EXAMPLES.md)
