---
name: writing-technical-design
description: Creates agent-optimized technical design documents with context-layer-aware progressive disclosure for architecture decisions, component design, and data models. Use when writing technical designs, architecture docs, defining system components, or making technology choices for spec-driven development.
---

# Writing Technical Design Documents

Create technical design documents that map architecture decisions to the right context management layers. Agents load design information only when making implementation choices.

**Use this skill when** designing how to build a feature, documenting architecture decisions, defining component interfaces, or specifying data models.

**Supporting files:** [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md) for layer mapping details, [EXAMPLES.md](references/EXAMPLES.md) for complete examples.

## Context Layer Distribution

Technical design information spans multiple context layers:

```
Layer   What goes here              File location
======================================================================
L1      Tech stack + feature ref    CLAUDE.md / AGENTS.md (constitution)
        "Go 1.23, Echo v4, PostgreSQL 16, sqlc"
        "specs/design-notifications.md - Notification architecture"

L2      Component-local patterns    .claude/rules/ or .github/instructions/
        "Handlers in this dir use async sender interface"
        "Repository pattern: no business logic in DB layer"

L3      Design body (this doc)      specs/design-{feature}.md
        Decision summary, component overview, interfaces

L4      Deep reference              specs/design-{feature}.md (lower sections)
        Alternatives considered, migration plan, ADR rationale
======================================================================
```

## Template: `specs/design-{feature-name}.md`

```markdown
---
title: "Feature Name - Technical Design"
status: draft | review | approved | implementing | done
prd: prd-feature-name.md
last-updated: YYYY-MM-DD
---

# Feature Name - Technical Design

## TL;DR

[2-3 sentences: Architecture approach and key trade-off.
Agent reads this to understand implementation direction.]

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| [Area] | [Technology/Pattern] | [Why, in one phrase] |
| [Area] | [Technology/Pattern] | [Why, in one phrase] |
| [Area] | [Technology/Pattern] | [Why, in one phrase] |

## Component Overview

```text
[ASCII diagram: components and data flow]

┌──────────┐     ┌──────────┐     ┌──────────┐
│  Client  │────>│ API GW   │────>│ Service  │
└──────────┘     └──────────┘     └────┬─────┘
                                       │
                                  ┌────▼─────┐
                                  │    DB     │
                                  └──────────┘

Arrows: ──> sync  ══> async  ··> optional
```

### [Component Name]

- **Responsibility**: [Single sentence]
- **Location**: `path/to/component/`
- **Interface**: [Key method signatures]
- **Depends on**: [Other components]

### [Component Name]

[Same structure]

## Interface Contracts

### [ComponentA] -> [ComponentB]

```go
type OrderService interface {
    CreateOrder(ctx context.Context, req CreateOrderRequest) (*Order, error)
    GetOrder(ctx context.Context, id string) (*Order, error)
}

type CreateOrderRequest struct {
    UserID string
    Items  []OrderItem
}
```

### Event Contracts

```json
{
  "event": "order.status_changed",
  "payload": {
    "order_id": "string (UUID)",
    "old_status": "string (enum: pending|processing|shipped|delivered)",
    "new_status": "string (enum)",
    "changed_at": "string (ISO8601)"
  }
}
```

## Data Model

```sql
CREATE TABLE orders (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES users(id),
    status     TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending','processing','shipped','delivered')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_orders_user_status ON orders(user_id, status);
```

### Entity Relationships

```text
User 1──* Order 1──* OrderItem *──1 Product
```

## Open Questions

- [ ] [Unresolved technical question] (@owner)
- [x] [Resolved question] -> Decision: [answer]

---
<!-- Below this line = L4 (deep reference) -->

## Alternatives Considered

### [Alternative Name]

- **Approach**: [Description]
- **Pros**: [Benefits]
- **Cons**: [Drawbacks]
- **Rejected because**: [Specific reason tied to requirements]

## Migration Plan

1. [Step] (rollback: [how to undo])
2. [Step] (rollback: [how to undo])

## ADR Log

| Date | Decision | Context | Consequences |
|------|----------|---------|-------------|
| YYYY-MM-DD | [What was decided] | [Why] | [Impact] |
```

## Writing Guidelines

### Decision Summary: The Agent's First Reference

When an agent starts implementing, it checks the decision summary table FIRST. This table prevents:
- Re-investigating technology choices already made
- Using the wrong pattern for this project
- Introducing inconsistent approaches

Write decisions as concrete choices, not vague directions:

```markdown
<!-- BAD -->
| Storage | Modern database | Best for our use case |

<!-- GOOD -->
| Storage | PostgreSQL 16 via sqlc | ACID for order state, sqlc for type-safe queries |
```

### Component Overview: Code Navigation Map

Agents need to know **where** to put new code. The `Location` field is critical -- it's what the agent uses to `Glob` or `Read` existing code:

```markdown
### Notification Sender

- **Responsibility**: Delivers push notifications via FCM/APNs
- **Location**: `internal/notification/sender/`
- **Interface**: `Send(ctx, userID, Notification) error`
- **Depends on**: `internal/notification/template/`, FCM SDK
```

### Interface Contracts: Write as Code

Agents implement against interface contracts. Write them as **actual type definitions and function signatures**, not prose descriptions:

```go
// The agent will implement this interface.
// Prose description would require interpretation; code is unambiguous.
type NotificationSender interface {
    Send(ctx context.Context, userID string, n Notification) error
    SendBatch(ctx context.Context, batch []NotificationRequest) []Result
}
```

### Data Model: DDL as Source of Truth

Write data models as executable DDL. Agents can use these directly to create migration files:

```sql
-- Include CHECK constraints: they serve as documentation AND validation
CREATE TABLE notifications (
    id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    channel TEXT NOT NULL CHECK (channel IN ('push', 'email', 'sms')),
    status  TEXT NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'sent', 'failed', 'read'))
);
```

### ASCII Diagrams: Keep Simple

Agents parse ASCII diagrams to understand data flow. Use consistent notation:

```text
──>  synchronous call
══>  asynchronous (event/queue)
··>  optional/conditional
─X─  blocked/denied
```

## L2 Integration: Extracting Component Rules

After finalizing the design, extract component-specific patterns into L2 conditional rules:

```markdown
<!-- .claude/rules/notification-service.md -->
---
paths:
  - "internal/notification/**/*.go"
---

Notification service patterns (from specs/design-notifications.md):
- Use NotificationSender interface for all delivery
- Never call FCM/APNs directly; go through sender abstraction
- Queue notifications via Redis Streams, never send in HTTP handler
- Use structured logging with slog for all operations
```

```markdown
<!-- .claude/rules/order-repository.md -->
---
paths:
  - "internal/order/repository/**/*.go"
---

Order repository patterns (from specs/design-notifications.md):
- Use sqlc-generated code; do not write raw SQL
- All queries must use context for cancellation
- Use partial indexes for status-based queries
```

This ensures agents working on specific code areas automatically get relevant architecture constraints without loading the full design document.

## Lifecycle

```
1. Start from approved feature spec (link in frontmatter prd field)
2. Write TL;DR with architecture approach
3. Fill decision summary table
4. Draw component diagram (ASCII)
5. Define interface contracts as code
6. Specify data model as DDL
7. Set status: "draft"
8. Add L1 reference to constitution
9. Review -> set status: "approved"
10. Extract component rules to L2 files
11. Create implementation tasks (writing-implementation-tasks skill)
12. During implementation -> set status: "implementing"
13. After completion -> set status: "done"
```

## Quality Checklist

```
Technical Design Quality Check:
- [ ] Links to feature spec in frontmatter (prd field)
- [ ] TL;DR states architecture approach and key trade-off
- [ ] Decision summary has concrete choices with rationale
- [ ] Every component has location, responsibility, interface
- [ ] Interface contracts are code, not prose
- [ ] Data model is DDL with constraints
- [ ] ASCII diagram shows component relationships
- [ ] No requirements in this doc (those belong in feature spec)
- [ ] L4 separator between core design and deep reference
- [ ] Component patterns extracted to L2 rules
- [ ] File named: specs/design-{feature-name}.md
```

## Detailed Guides

**Context layer mapping details**: See [CONTEXT-LAYERS.md](references/CONTEXT-LAYERS.md)
**Complete design doc examples**: See [EXAMPLES.md](references/EXAMPLES.md)
